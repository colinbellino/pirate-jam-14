package engine_v2

import "core:c"
import "core:fmt"
import "core:log"
import "core:math/linalg"
import "core:mem"
import "core:runtime"
import "core:strings"
import "vendor:sdl2"
import gl "vendor:OpenGL"
import stb_image "vendor:stb/image"

// TODO: move to engine_math
Vector2i32 :: distinct [2]i32
Vector2f32 :: distinct [2]f32
Vector3f32 :: distinct [3]f32
Vector4f32 :: distinct [4]f32

State :: struct {
    // Platform
    window:                 ^Window,
    gl_context:             GL_Context,
    quit_requested:         bool,
    window_resized:         bool,
    frame_stat:             Frame_Stat,
    keys:                   map[Scancode]Key_State,
    mouse_keys:             map[Mouse_Button]Key_State,
    mouse_position:         Vector2i32,
    mouse_wheel:            Vector2i32,
    mouse_moved:            bool,
    input_text:             string,
    controllers:            map[Joystick_ID]Controller_State,
}

Frame_Stat :: struct {
    fps:            f32,
    sleep_time:     f32,
    target_fps:     f32,
    delta_time:     f32,
    start:          u64,
}

Controller_State :: struct {
    controller:     ^Game_Controller,
    buttons:        map[Game_Controller_Button]Key_State,
    axes:           map[Game_Controller_Axis]Axis_State,
}

Key_State :: struct {
    down:           bool, // The key is down
    pressed:        bool, // The key was pressed this frame
    released:       bool, // The key was released this frame
}

Axis_State :: struct {
    value:          i16,
}

Mouse_Button :: enum {
    Left    = sdl2.BUTTON_LEFT,
    Middle  = sdl2.BUTTON_MIDDLE,
    Right   = sdl2.BUTTON_RIGHT,
}

Window                  :: sdl2.Window
GL_Context              :: sdl2.GLContext
Event                   :: sdl2.Event
Keycode                 :: sdl2.Keycode
Scancode                :: sdl2.Scancode
Joystick_ID             :: sdl2.JoystickID
Game_Controller         :: sdl2.GameController
Game_Controller_Button  :: sdl2.GameControllerButton
Game_Controller_Axis    :: sdl2.GameControllerAxis

GL_DESIRED_MAJOR_VERSION :: 3
GL_DESIRED_MINOR_VERSION :: 3

@(private) state: ^State

open_window :: proc(screen_width, screen_height: i32) -> rawptr {
    state = new(State)

    if sdl_res := sdl2.Init(sdl2.INIT_EVERYTHING); sdl_res < 0 {
        fmt.panicf("sdl2.init returned %v.", sdl_res)
    }

    state.window = sdl2.CreateWindow("", sdl2.WINDOWPOS_UNDEFINED, sdl2.WINDOWPOS_UNDEFINED, screen_width, screen_height, { .SHOWN, .OPENGL })
    if state.window == nil {
        fmt.panicf("sdl2.CreateWindow failed.\n")
    }
    sdl2.GL_SetSwapInterval(0)

    for key in Scancode {
        state.keys[key] = Key_State { }
    }
    for button in Mouse_Button {
        state.mouse_keys[button] = Key_State { }
    }
    state.frame_stat.target_fps = f32(get_refresh_rate())

    return state
}

init :: proc(new_state: rawptr) {
    if new_state != nil {
        state = cast(^State) new_state
    }

    {
        sdl2.GL_SetAttribute(.CONTEXT_PROFILE_MASK, i32(sdl2.GLprofile.CORE))

        gl.load_up_to(GL_DESIRED_MAJOR_VERSION, GL_DESIRED_MINOR_VERSION, proc(ptr: rawptr, name: cstring) {
            (cast(^rawptr)ptr)^ = sdl2.GL_GetProcAddress(name)
        })

        state.gl_context = sdl2.GL_CreateContext(state.window)
        if state.gl_context == nil {
            fmt.panicf("sdl2.GL_CreateContext error: %v.\n", sdl2.GetError())
        }
        log.debugf("GL version: %s", gl.GetString(gl.VERSION))
    }

    sokol_init()
    ui_init(state.window, state.gl_context)
}

quit :: proc() {
    ui_quit()
    sokol_quit()
}

free_memory :: proc() {
    free(state)
    delete(state.keys)
    delete(state.mouse_keys)
}

frame_begin :: proc() {
    state.frame_stat.start = sdl2.GetPerformanceCounter()
    reset_frame_state()
    process_inputs()
    ui_frame_begin()
}

frame_end :: proc() {
    ui_frame_end()

    sdl2.GL_SwapWindow(state.window)

    update_frame_stat(&state.frame_stat)
    if state.frame_stat.sleep_time > 0 {
        sdl2.Delay(u32(state.frame_stat.sleep_time))
    }
}

get_refresh_rate :: proc() -> (refresh_rate: i32 = 60) {
    display_mode: sdl2.DisplayMode
    display_index := sdl2.GetWindowDisplayIndex(state.window)
    if sdl2.GetCurrentDisplayMode(display_index, &display_mode) == 0 && display_mode.refresh_rate > 0 {
        return display_mode.refresh_rate
    }
    return
}

get_fps :: proc() -> f32 {
    return state.frame_stat.fps
}

should_quit :: proc() -> bool {
    return state.quit_requested
}

reset_frame_state :: proc() {
    for key in Scancode {
        (&state.keys[key]).released = false
        (&state.keys[key]).pressed = false
    }
    for key in state.mouse_keys {
        (&state.mouse_keys[key]).released = false
        (&state.mouse_keys[key]).pressed = false
    }
    for _, controller_state in state.controllers {
        for key in controller_state.buttons {
            (&controller_state.buttons[key]).released = false
            (&controller_state.buttons[key]).pressed = false
        }
    }
    state.input_text = ""
    state.mouse_wheel.x = 0
    state.mouse_wheel.y = 0
    state.mouse_moved = false

    state.window_resized = false
}

@(private) process_inputs :: proc() {
    e: Event
    for sdl2.PollEvent(&e) {
        ui_process_event(&e)

        #partial switch e.type {
            case .QUIT:
                state.quit_requested = true

            case .WINDOWEVENT: {
                window_event := (^sdl2.WindowEvent)(&e)^
                #partial switch window_event.event {
                    case .RESIZED: {
                        state.window_resized = true
                    }
                    case .SHOWN: {
                        state.window_resized = true
                    }
                    // case: {
                    //     log.debugf("window_event: %v", window_event)
                    // }
                }
            }

            case .TEXTINPUT: {
                state.input_text = string(cstring(&e.text.text[0]))
            }

            case .MOUSEMOTION: {
                state.mouse_position.x = e.motion.x
                state.mouse_position.y = e.motion.y
                state.mouse_moved = true
            }
            case .MOUSEBUTTONDOWN, .MOUSEBUTTONUP: {
                key := &state.mouse_keys[cast(Mouse_Button) e.button.button]
                key.down = e.type == .MOUSEBUTTONDOWN
                key.released = e.type == .MOUSEBUTTONUP
                key.pressed = e.type == .MOUSEBUTTONDOWN
            }
            case .MOUSEWHEEL: {
                state.mouse_wheel.x = e.wheel.x
                state.mouse_wheel.y = e.wheel.y
            }

            case .KEYDOWN, .KEYUP: {
                key := &state.keys[e.key.keysym.scancode]
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
                            buttons := map[Game_Controller_Button]Key_State {}
                            for button in Game_Controller_Button {
                                buttons[button] = Key_State {}
                            }
                            axes := map[Game_Controller_Axis]Axis_State {}
                            for axis in Game_Controller_Axis {
                                axes[axis] = Axis_State {}
                            }
                            state.controllers[joystick_id] = { controller, buttons, axes }
                            controller_name := get_controller_name(controller)
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
                joystick_id := cast(Joystick_ID) controller_event.which

                controller_state, controller_found := state.controllers[joystick_id]
                if controller_found {
                    controller_name := get_controller_name(controller_state.controller)
                    log.infof("Controller removed: %v (%v)", controller_name, joystick_id)

                    sdl2.GameControllerClose(controller_state.controller)
                    delete_key(&state.controllers, joystick_id)
                }
            }

            case .CONTROLLERBUTTONDOWN, .CONTROLLERBUTTONUP: {
                controller_button_event := (^sdl2.ControllerButtonEvent)(&e)^
                joystick_id := controller_button_event.which
                button := cast(Game_Controller_Button) controller_button_event.button

                controller_state, controller_found := state.controllers[joystick_id]
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
                axis := cast(Game_Controller_Axis) controller_axis_event.axis

                controller_state, controller_found := state.controllers[joystick_id]
                if controller_found {
                    axis := &controller_state.axes[axis]
                    axis.value = controller_axis_event.value
                }
            }
        }
    }
}

mouse_button_is_down :: proc(button: Mouse_Button) -> bool {
    return state.mouse_keys[button].down
}

get_mouse_position :: proc() -> Vector2i32 {
    return state.mouse_position
}

get_controller_name :: proc(controller: ^Game_Controller) -> string {
    return string(sdl2.GameControllerName(controller))
}

get_controller_from_player_index :: proc(player_index: int) -> (controller_state: ^Controller_State, found: bool) {
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
    controller_state, controller_found = &state.controllers[joystick_id]
    if controller_found != true {
        return
    }
    return controller_state, true
}

set_window_title :: proc(title: string, args: ..any) {
    sdl2.SetWindowTitle(state.window, strings.clone_to_cstring(fmt.tprintf(title, ..args), context.temp_allocator))
}

get_window_size :: proc () -> Vector2i32 {
    window := state.window
    window_width: i32
    window_height: i32
    sdl2.GetWindowSize(window, &window_width, &window_height)
    if window_width == 0 || window_height == 0 {
        log.errorf("sdl2.GetWindowSize error: %v.", sdl2.GetError())
        return { 0, 0 }
    }
    return { window_width, window_height }
}

update_frame_stat :: proc(stat: ^Frame_Stat) {
    frame_end := sdl2.GetPerformanceCounter()
    delta_time := f32(frame_end - stat.start) * 1_000 / f32(sdl2.GetPerformanceFrequency())
    target_frame_time := 1_000 / stat.target_fps
    stat.sleep_time = target_frame_time - delta_time
    stat.fps = 1_000 / delta_time
    stat.delta_time = delta_time
}

@(private) sokol_alloc_fn :: proc "c" (size: u64, user_data: rawptr) -> rawptr {
    context = runtime.default_context()
    ptr, err := mem.alloc(int(size))
    if err != .None { log.errorf("sokol_alloc_fn: %v", err) }
    return ptr
}

@(private) sokol_free_fn :: proc "c" (ptr: rawptr, user_data: rawptr) {
    context = runtime.default_context()
    err := mem.free(ptr)
    if err != .None { log.errorf("sokol_free_fn: %v", err) }
}
