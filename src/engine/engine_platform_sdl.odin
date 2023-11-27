package engine

import "core:c"
import "core:fmt"
import "core:log"
import "core:math"
import "core:mem"
import "core:os"
import "core:runtime"
import "core:strings"
import "core:time"
import "vendor:sdl2"
import stb_image "vendor:stb/image"
import "../tools"

Keycode              :: sdl2.Keycode
Scancode             :: sdl2.Scancode
Window               :: sdl2.Window
JoystickID           :: sdl2.JoystickID
GameController       :: sdl2.GameController
GameControllerButton :: sdl2.GameControllerButton
GameControllerAxis   :: sdl2.GameControllerAxis

Platform_State :: struct {
    arena:                  Named_Virtual_Arena,
    window:                 ^Window,
    quit_requested:         bool,
    window_resized:         bool,
    window_size:            Vector2i32,

    keys:                   map[Scancode]Key_State,
    mouse_keys:             map[i32]Key_State,
    mouse_position:         Vector2i32,
    mouse_wheel:            Vector2i32,
    mouse_moved:            bool,
    input_text:             string,
    controllers:            map[JoystickID]Controller_State,

    performance_frequency:  f32,
    frame_ctx:              ZoneCtx,
    frame_count:            i64,
    frame_start:            u64,
    frame_end:              u64,
    frame_delay:            f32,
    frame_duration:         f32,
    delta_time:             f32, // TODO: move to core
    actual_fps:             i32,
    locked_fps:             i32,
}

Controller_State :: struct {
    controller: ^GameController,
    buttons:    map[GameControllerButton]Key_State,
    axes:       map[GameControllerAxis]Axis_State,
}

Key_State :: struct {
    down:       bool, // The key is down
    pressed:    bool, // The key was pressed this frame
    released:   bool, // The key was released this frame
}

Axis_State :: struct {
    value:      i16,
}

BUTTON          :: sdl2.BUTTON
BUTTON_LEFT     :: sdl2.BUTTON_LEFT
BUTTON_MIDDLE   :: sdl2.BUTTON_MIDDLE
BUTTON_RIGHT    :: sdl2.BUTTON_RIGHT

PROFILER_COLOR_RENDER :: PROFILER_COLOR_ENGINE
PLATFORM_ARENA_SIZE   :: mem.Megabyte

@(private="package")
_platform: ^Platform_State

platform_init :: proc() -> (platform_state: ^Platform_State, ok: bool) #optional_ok {
    profiler_zone("platform_init", PROFILER_COLOR_ENGINE)

    log.infof("Platform (SDL) ---------------------------------------------")
    defer log_ok(ok)

    _platform = mem_named_arena_virtual_bootstrap_new_or_panic(Platform_State, "arena", PLATFORM_ARENA_SIZE, "platform")
    context.allocator = _platform.arena.allocator

    error := sdl2.Init({ .VIDEO, .GAMECONTROLLER })
    if error != 0 {
        log.errorf("sdl2.Init error: %v.", error)
        return
    }

    version: sdl2.version
    sdl2.GetVersion(&version)

    for key in Scancode {
        _platform.keys[key] = Key_State { }
    }
    _platform.mouse_keys[BUTTON_LEFT] = Key_State { }
    _platform.mouse_keys[BUTTON_MIDDLE] = Key_State { }
    _platform.mouse_keys[BUTTON_RIGHT] = Key_State { }

    _platform.performance_frequency = f32(sdl2.GetPerformanceFrequency())

    log.infof("  SDL version:          %v.%v.%v", version.major, version.minor, version.patch)

    platform_state = _platform
    ok = true
    return
}

platform_quit :: proc() {
    // sdl2.Quit()
}

platform_reload :: proc(platform_state: ^Platform_State) {
    assert(platform_state != nil)
    _platform = platform_state
}

platform_open_window :: proc(window_size: Vector2i32) -> (ok: bool) {
    context.allocator = _platform.arena.allocator
    profiler_zone("platform_open_window", PROFILER_COLOR_ENGINE)
    assert(_platform != nil, "Platform not initialized.")

    _platform.window = sdl2.CreateWindow(
        nil,
        sdl2.WINDOWPOS_UNDEFINED, sdl2.WINDOWPOS_UNDEFINED,
        window_size.x, window_size.y, { .SHOWN, .RESIZABLE, .ALLOW_HIGHDPI, .OPENGL },
    )
    if _platform.window == nil {
        log.errorf("sdl2.CreateWindow error: %v.", sdl2.GetError())
        return
    }

    _platform.window_size = platform_get_window_size(_platform.window)

    ok = true
    return
}
platform_close_window :: proc() {
    sdl2.DestroyWindow(_platform.window)
}

@(deferred_out=platform_frame_end)
platform_frame :: proc() {
    platform_frame_begin()
}

platform_frame_begin :: proc() {
    profiler_frame_mark_start()
    _platform.frame_ctx = profiler_zone_begin(fmt.tprintf("Frame %v", _platform.frame_count))
    _platform.frame_start = sdl2.GetPerformanceCounter()

    platform_process_events()
    renderer_render_begin()
}

platform_frame_end :: proc() {
    {
        profiler_zone("platform_frame_end", PROFILER_COLOR_ENGINE)

        renderer_render_end()
        platform_reset_inputs()
        platform_reset_events()

        gpu_duration: f32
        refresh_rate: i32 = 999999

        if renderer_is_enabled() {
            // All timings here are in milliseconds
            refresh_rate = _renderer.refresh_rate
            gpu_duration = f32(_renderer.draw_duration) / 1_000_000
        }

        frame_end := sdl2.GetPerformanceCounter()
        performance_frequency := _platform.performance_frequency
        cpu_duration := f32(frame_end - _platform.frame_start) * 1_000 / performance_frequency
        frame_budget : f32 = 1_000 / f32(refresh_rate)
        frame_duration := cpu_duration + f32(gpu_duration)
        frame_delay := max(0, frame_budget - frame_duration)
        // log.debugf("cpu %.5fms | gpu %.5fms | delta_time %v", cpu_duration, gpu_duration, _platform.delta_time);

        // FIXME: not sure if sdl2.Delay() is the best way here
        // FIXME: we don't want to freeze since we still want to do some things as fast as possible (ie: inputs)
        {
            profiler_zone("delay", PROFILER_COLOR_ENGINE)
            sdl2.Delay(u32(frame_delay))
        }

        _platform.locked_fps = i32(1_000 / (frame_duration + frame_delay))
        _platform.actual_fps = i32(1_000 / frame_duration)
        _platform.frame_delay = frame_delay
        _platform.frame_duration = frame_duration
        _platform.frame_end = frame_end
        _platform.delta_time = f32(sdl2.GetPerformanceCounter() - _platform.frame_start) * 1000 / performance_frequency
        _platform.frame_count += 1
    }

    free_all(context.temp_allocator)
    file_watch_update()

    profiler_zone_end(_platform.frame_ctx)
    profiler_frame_mark_end()
}

platform_process_events :: proc() {
    profiler_zone("platform_process_events", PROFILER_COLOR_ENGINE)

    e: sdl2.Event
    for sdl2.PollEvent(&e) {
        renderer_process_events(&e)

        #partial switch e.type {
            case .QUIT:
                _platform.quit_requested = true

            case .WINDOWEVENT: {
                window_event := (^sdl2.WindowEvent)(&e)^
                #partial switch window_event.event {
                    case .RESIZED: {
                        _platform.window_resized = true
                    }
                    case .SHOWN: {
                        _platform.window_resized = true
                    }
                    // case: {
                    //     log.debugf("window_event: %v", window_event)
                    // }
                }
            }

            case .TEXTINPUT: {
                _platform.input_text = string(cstring(&e.text.text[0]))
            }

            case .MOUSEMOTION: {
                _platform.mouse_position.x = e.motion.x
                _platform.mouse_position.y = e.motion.y
                _platform.mouse_moved = true
            }
            case .MOUSEBUTTONDOWN, .MOUSEBUTTONUP: {
                key := &_platform.mouse_keys[i32(e.button.button)]
                key.down = e.type == .MOUSEBUTTONDOWN
                key.released = e.type == .MOUSEBUTTONUP
                key.pressed = e.type == .MOUSEBUTTONDOWN
            }
            case .MOUSEWHEEL: {
                _platform.mouse_wheel.x = e.wheel.x
                _platform.mouse_wheel.y = e.wheel.y
            }

            case .KEYDOWN, .KEYUP: {
                key := &_platform.keys[e.key.keysym.scancode]
                key.down = e.type == .KEYDOWN
                key.released = e.type == .KEYUP
                key.pressed = e.type == .KEYDOWN
            }

            case .CONTROLLERDEVICEADDED: {
                controller_event := (^sdl2.ControllerDeviceEvent)(&e)^
                joystick_index := controller_event.which

                if sdl2.IsGameController(controller_event.which) {
                    controller := sdl2.GameControllerOpen(controller_event.which)
                    if controller != nil {
                        joystick := sdl2.GameControllerGetJoystick(controller)

                        joystick_id := sdl2.JoystickInstanceID(joystick)
                        if joystick_id < 0 {
                            log.error("JoystickInstanceID error")
                        } else {
                            buttons := map[GameControllerButton]Key_State {}
                            for button in GameControllerButton {
                                buttons[button] = Key_State {}
                            }
                            axes := map[GameControllerAxis]Axis_State {}
                            for axis in GameControllerAxis {
                                axes[axis] = Axis_State {}
                            }
                            _platform.controllers[joystick_id] = { controller, buttons, axes }
                            controller_name := platform_get_controller_name(controller)
                            log.infof("Controller added  : %v (%v)", controller_name, joystick_id)
                        }
                    } else {
                        log.error("GameControllerOpen error")
                    }
                } else {
                    log.error("IsGameController error")
                }
            }

            case .CONTROLLERDEVICEREMOVED: {
                controller_event := (^sdl2.ControllerDeviceEvent)(&e)^
                joystick_id := JoystickID(controller_event.which)

                controller_state, controller_found := _platform.controllers[joystick_id]
                if controller_found {
                    controller_name := platform_get_controller_name(controller_state.controller)
                    log.infof("Controller removed: %v (%v)", controller_name, joystick_id)

                    sdl2.GameControllerClose(controller_state.controller)
                    delete_key(&_platform.controllers, joystick_id)
                }
            }

            case .CONTROLLERBUTTONDOWN, .CONTROLLERBUTTONUP: {
                controller_button_event := (^sdl2.ControllerButtonEvent)(&e)^
                joystick_id := controller_button_event.which
                button := GameControllerButton(controller_button_event.button)

                controller_state, controller_found := _platform.controllers[joystick_id]
                if controller_found {
                    key := &controller_state.buttons[button]
                    key.down = controller_button_event.state == sdl2.PRESSED
                    key.released = controller_button_event.state == sdl2.RELEASED
                    key.pressed = controller_button_event.state == sdl2.PRESSED
                }
            }

            case .CONTROLLERAXISMOTION: {
                controller_axis_event := (^sdl2.ControllerAxisEvent)(&e)^
                joystick_id := controller_axis_event.which
                axis := GameControllerAxis(controller_axis_event.axis)

                controller_state, controller_found := _platform.controllers[joystick_id]
                if controller_found {
                    axis := &controller_state.axes[axis]
                    axis.value = controller_axis_event.value
                }
            }
        }
    }
}

platform_get_controller_name :: proc(controller: ^GameController) -> string {
    return string(sdl2.GameControllerName(controller))
}

platform_get_controller_from_player_index :: proc(player_index: int) -> (controller_state: ^Controller_State, found: bool) {
    controller := sdl2.GameControllerFromPlayerIndex(c.int(player_index))
    if controller == nil {
        return
    }
    joystick := sdl2.GameControllerGetJoystick(controller)
    if joystick == nil {
        return
    }
    joystick_id := sdl2.JoystickInstanceID(joystick)
    if joystick_id < 0 {
        return
    }
    controller_found: bool
    controller_state, controller_found = &_platform.controllers[joystick_id]
    if controller_found != true {
        return
    }
    return controller_state, true
}

platform_load_image :: proc(filepath: string, width, height, channels_in_file: ^i32, desired_channels: i32 = 0) -> [^]byte {
    // stb_image.set_flip_vertically_on_load(1)
    return stb_image.load(strings.clone_to_cstring(filepath, context.temp_allocator), width, height, channels_in_file, desired_channels)
}

platform_get_ticks :: proc() -> u32 {
    return sdl2.GetTicks()
}

platform_set_window_size :: proc(window: ^Window, size: Vector2i32) {
    sdl2.SetWindowSize(window, size.x, size.y)
    platform_resize_window()
}

platform_get_window_size :: proc (window: ^Window) -> Vector2i32 {
    window_width: i32
    window_height: i32
    sdl2.GetWindowSize(window, &window_width, &window_height)
    if window_width == 0 || window_height == 0 {
        log.errorf("sdl2.GetWindowSize error: %v.", sdl2.GetError())
        return { 0, 0 }
    }
    return { window_width, window_height }
}

platform_reset_inputs :: proc() {
    profiler_zone("reset_inputs", PROFILER_COLOR_ENGINE)

    for key in Scancode {
        (&_platform.keys[key]).released = false
        (&_platform.keys[key]).pressed = false
    }
    for key in _platform.mouse_keys {
        (&_platform.mouse_keys[key]).released = false
        (&_platform.mouse_keys[key]).pressed = false
    }
    for _, controller_state in _platform.controllers {
        for key in controller_state.buttons {
            (&controller_state.buttons[key]).released = false
            (&controller_state.buttons[key]).pressed = false
        }
    }
    _platform.input_text = ""
    _platform.mouse_wheel.x = 0
    _platform.mouse_wheel.y = 0
    _platform.mouse_moved = false
}

platform_reset_events :: proc() {
    _platform.window_resized = false
}

platform_set_window_title :: proc(title: string) {
    sdl2.SetWindowTitle(_platform.window, strings.clone_to_cstring(title, context.temp_allocator))
}

platform_resize_window :: proc() {
    if renderer_is_enabled() == false { return }

    _platform.window_size = platform_get_window_size(_platform.window)
    _renderer.pixel_density = renderer_get_window_pixel_density(_platform.window)
    _renderer.refresh_rate = platform_get_refresh_rate(_platform.window)

    renderer_update_viewport()

    log.infof("Window resized ---------------------------------------------")
    log.infof("  Window size:          %v", _platform.window_size)
    log.infof("  Refresh rate:         %v", _renderer.refresh_rate)
    log.infof("  Pixel density:        %v", _renderer.pixel_density)
    log.infof("------------------------------------------------------------")
}

platform_get_refresh_rate :: proc(window: ^Window) -> i32 {
    refresh_rate : i32 = 60
    display_mode: sdl2.DisplayMode
    display_index := sdl2.GetWindowDisplayIndex(window)
    if sdl2.GetCurrentDisplayMode(display_index, &display_mode) == 0 && display_mode.refresh_rate > 0 {
        refresh_rate = display_mode.refresh_rate
    }
    return refresh_rate
}

Input_Repeater :: struct {
    value:         Vector2i32,
    threshold:     time.Duration,
    multiple_axis: bool,
    rate:          time.Duration,
    next:          time.Time,
    hold:          bool,
}

platform_process_repeater :: proc(repeater: ^Input_Repeater, raw_value: Vector2f32) {
    value := Vector2i32 { i32(math.round(raw_value.x)), i32(math.round(raw_value.y)) }
    repeater.value = { 0, 0 }

    if vector_not_equal(value, 0) {
        now := time.now()

        if repeater.multiple_axis == false {
            if math.abs(value.x) > math.abs(value.y) {
                value.y = 0
            } else {
                value.x = 0
            }
        }

        if time.diff(repeater.next, now) >= 0 {
            offset := repeater.hold ? repeater.rate : repeater.threshold
            repeater.hold = true
            repeater.next = time.time_add(now, offset)
            repeater.value = value
        }
    } else {
        repeater.hold = false
        repeater.next = { 0 }
    }
}
