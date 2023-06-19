package engine

import "core:c"
import "core:log"
import "core:mem"
import "core:runtime"
import "core:strings"
import "vendor:sdl2"
import "vendor:stb/image"

Surface              :: sdl2.Surface
Keycode              :: sdl2.Keycode
Scancode             :: sdl2.Scancode
Window               :: sdl2.Window
JoystickID           :: sdl2.JoystickID
GameController       :: sdl2.GameController
GameControllerButton :: sdl2.GameControllerButton
GameControllerAxis   :: sdl2.GameControllerAxis

BUTTON          :: sdl2.BUTTON
BUTTON_LEFT     :: sdl2.BUTTON_LEFT
BUTTON_MIDDLE   :: sdl2.BUTTON_MIDDLE
BUTTON_RIGHT    :: sdl2.BUTTON_RIGHT

APP_BASE_ADDRESS        :: 2 * mem.Terabyte
APP_ARENA_SIZE          :: 8 * mem.Megabyte
TIME_HISTORY_COUNT      :: 4
SNAP_FREQUENCY_COUNT    :: 5
PROFILER_COLOR_RENDER   :: 0x005500

Platform_State :: struct {
    arena:                  ^mem.Arena,
    window:                 ^Window,
    quit_requested:         bool,
    window_resized:         bool,

    keys:                   map[Scancode]Key_State,
    mouse_keys:             map[i32]Key_State,
    mouse_position:         Vector2i,
    input_text:             string,
    input_scroll:           Vector2i,
    controllers:            map[JoystickID]Controller_State,

    frame_start:            u64,
    delta_time:             f32,
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

platform_init :: proc(allocator: mem.Allocator, temp_allocator: mem.Allocator, profiler_enabled: bool) -> (ok: bool) {
    profiler_zone("platform_init")
    context.allocator = allocator

    _engine.platform = new(Platform_State)
    if profiler_enabled {
        _engine.platform.arena = cast(^mem.Arena)(cast(^ProfiledAllocatorData)allocator.data).backing_allocator.data
    } else {
        _engine.platform.arena = cast(^mem.Arena)allocator.data
    }

    error := sdl2.Init({ .VIDEO, .AUDIO, .GAMECONTROLLER })
    if error != 0 {
        log.errorf("sdl2.Init error: %v.", error)
        return
    }

    for key in Scancode {
        _engine.platform.keys[key] = Key_State { }
    }
    _engine.platform.mouse_keys[BUTTON_LEFT] = Key_State { }
    _engine.platform.mouse_keys[BUTTON_MIDDLE] = Key_State { }
    _engine.platform.mouse_keys[BUTTON_RIGHT] = Key_State { }

    ok = true
    return
}

platform_open_window :: proc(title: string, size: Vector2i) -> (ok: bool) {
    profiler_zone("platform_open_window")
    context.allocator = _engine.arena_allocator

    _engine.platform.window = sdl2.CreateWindow(
        strings.clone_to_cstring(title),
        sdl2.WINDOWPOS_UNDEFINED, sdl2.WINDOWPOS_UNDEFINED,
        size.x, size.y, { .SHOWN, .RESIZABLE, .ALLOW_HIGHDPI, .OPENGL },
    )
    if _engine.platform.window == nil {
        log.errorf("sdl2.CreateWindow error: %v.", sdl2.GetError())
        return
    }

    if renderer_init(_engine.platform.window, _engine.arena_allocator) == false {
        log.error("Couldn't renderer_init correctly.")
        return
    }
    assert(_engine.renderer != nil, "renderer not initialized correctly!")

    if ui_init() == false {
        log.error("Couldn't ui_init correctly.")
        return
    }
    assert(_engine.ui != nil, "ui not initialized correctly!")

    ok = true
    return
}
platform_close_window :: proc() {
    sdl2.DestroyWindow(_engine.platform.window)
}

platform_frame_start :: proc() {
    _engine.platform.frame_start = sdl2.GetPerformanceCounter()

    platform_process_events()
}

platform_frame_end :: proc() {
    platform_reset_inputs()
    platform_reset_events()
    profiler_frame_mark()

    frame_end := sdl2.GetPerformanceCounter()
    _engine.platform.delta_time = f32(frame_end - _engine.platform.frame_start) / f32(sdl2.GetPerformanceFrequency())
    log.debugf("FPS: %v", (1.0 / _engine.platform.delta_time));
}

platform_process_events :: proc() {
    profiler_zone("process_events", 0x005500)

    context.allocator = _engine.arena_allocator
    e: sdl2.Event

    for sdl2.PollEvent(&e) {
        #partial switch e.type {
            case .QUIT:
                _engine.platform.quit_requested = true

            case .WINDOWEVENT: {
                window_event := (^sdl2.WindowEvent)(&e)^
                #partial switch window_event.event {
                    case .RESIZED: {
                        _engine.platform.window_resized = true
                    }
                    case .SHOWN: {
                        _engine.platform.window_resized = true
                    }
                    // case: {
                    //     log.debugf("window_event: %v", window_event)
                    // }
                }
            }

            case .TEXTINPUT: {
                _engine.platform.input_text = string(cstring(&e.text.text[0]))
            }

            case .MOUSEMOTION: {
                _engine.platform.mouse_position.x = e.motion.x
                _engine.platform.mouse_position.y = e.motion.y
            }
            case .MOUSEBUTTONDOWN, .MOUSEBUTTONUP: {
                key := &_engine.platform.mouse_keys[i32(e.button.button)]
                key.down = e.type == .MOUSEBUTTONDOWN
                key.released = e.type == .MOUSEBUTTONUP
                key.pressed = e.type == .MOUSEBUTTONDOWN
            }
            case .MOUSEWHEEL: {
                _engine.platform.input_scroll.x = e.wheel.x
                _engine.platform.input_scroll.y = e.wheel.y
            }

            case .KEYDOWN, .KEYUP: {
                key := &_engine.platform.keys[e.key.keysym.scancode]
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
                            _engine.platform.controllers[joystick_id] = { controller, buttons, axes }
                            controller_name := platform_get_controller_name(controller)
                            log.infof("Controller added: %v (%v)", controller_name, joystick_id)
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

                controller_state, controller_found := _engine.platform.controllers[joystick_id]
                if controller_found {
                    controller_name := platform_get_controller_name(controller_state.controller)
                    log.infof("Controller removed: %v (%v)", controller_name, joystick_id)

                    sdl2.GameControllerClose(controller_state.controller)
                    delete_key(&_engine.platform.controllers, joystick_id)
                }
            }

            case .CONTROLLERBUTTONDOWN, .CONTROLLERBUTTONUP: {
                controller_button_event := (^sdl2.ControllerButtonEvent)(&e)^
                joystick_id := JoystickID(controller_button_event.which)
                button := GameControllerButton(controller_button_event.button)

                controller_state, controller_found := _engine.platform.controllers[joystick_id]
                if controller_found {
                    key := &controller_state.buttons[button]
                    key.down = controller_button_event.state == sdl2.PRESSED
                    key.released = controller_button_event.state == sdl2.RELEASED
                    key.pressed = controller_button_event.state == sdl2.PRESSED
                }
            }

            case .CONTROLLERAXISMOTION: {
                controller_axis_event := (^sdl2.ControllerAxisEvent)(&e)^
                joystick_id := JoystickID(controller_axis_event.which)
                axis := GameControllerAxis(controller_axis_event.axis)

                controller_state, controller_found := _engine.platform.controllers[joystick_id]
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
    controller_state, controller_found = &_engine.platform.controllers[joystick_id]
    if controller_found != true {
        return
    }
    return controller_state, true
}

platform_load_surface_from_image_file :: proc(image_path: string, allocator: runtime.Allocator) -> (surface: ^Surface, ok: bool) {
    context.allocator = allocator

    path := strings.clone_to_cstring(image_path)
    defer delete(path)

    if strings.has_suffix(image_path, ".bmp") {
        surface = sdl2.LoadBMP(path)
    } else {
        width, height, channels_in_file: i32
        data := image.load(path, &width, &height, &channels_in_file, 0)
        // defer image.image_free(data)

        // Convert into an SDL2 Surface.
        rmask := u32(0x000000ff)
        gmask := u32(0x0000ff00)
        bmask := u32(0x00ff0000)
        amask := u32(0xff000000) if channels_in_file == 4 else u32(0x0)
        pitch := ((width * channels_in_file) + 3) & ~i32(3)
        depth := channels_in_file * 8

        surface = sdl2.CreateRGBSurfaceFrom(
            data,
            width, height, depth, pitch,
            rmask, gmask, bmask, amask,
        )
    }


    if surface == nil {
        log.errorf("Couldn't load image: %v.", image_path)
        return
    }

    ok = true
    return
}

platform_free_surface :: proc(surface: ^Surface) {
    sdl2.FreeSurface(surface)
}

platform_get_window_size :: proc (window: ^Window) -> Vector2i {
    window_width : i32 = 0
    window_height : i32 = 0
    sdl2.GetWindowSize(window, &window_width, &window_height)
    return { window_width, window_height }
}

platform_reset_inputs :: proc() {
    profiler_zone("reset_inputs")

    for key in Scancode {
        (&_engine.platform.keys[key]).released = false
        (&_engine.platform.keys[key]).pressed = false
    }
    for key in _engine.platform.mouse_keys {
        (&_engine.platform.mouse_keys[key]).released = false
        (&_engine.platform.mouse_keys[key]).pressed = false
    }
    for _, controller_state in _engine.platform.controllers {
        for key in controller_state.buttons {
            (&controller_state.buttons[key]).released = false
            (&controller_state.buttons[key]).pressed = false
        }
    }
    _engine.platform.input_text = ""
    _engine.platform.input_scroll.x = 0
    _engine.platform.input_scroll.y = 0
}

platform_reset_events :: proc() {
    _engine.platform.window_resized = false
}
