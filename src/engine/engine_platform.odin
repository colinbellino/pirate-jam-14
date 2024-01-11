package engine

import "core:log"
import "core:mem"
import "core:fmt"
import "core:time"
import "core:math"
import "core:c"
import "core:strings"
import "vendor:sdl2"
import stb_image "vendor:stb/image"
import gl "vendor:OpenGL"
import "../tools"

Platform_State :: struct {
    arena:                  tools.Named_Virtual_Arena,
    window:                 ^Window,
    gl_context:             GL_Context,
    quit_requested:         bool,
    window_resized:         bool,
    frame_stat:             Frame_Stat,
    inputs:                 Inputs,
}

Inputs :: struct {
    keyboard_was_used:      bool,
    keys:                   map[Scancode]Key_State,
    mouse_keys:             map[Mouse_Button]Key_State,
    mouse_position:         Vector2i32,
    mouse_wheel:            Vector2i32,
    mouse_moved:            bool,
    input_text:             string,
    controller_was_used:    bool,
    controllers:            map[Joystick_ID]Controller_State,
}

Frame_Stat :: struct {
    fps:            f32,
    target_fps:     f32,
    delta_time:     f32,
    cpu_time:       f32,
    gpu_time:       f32,
    sleep_time:     f32,
    start:          u64,
    gpu_start:      u64,
    count:          i64,
    ctx:            ZoneCtx,
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

Window                   :: sdl2.Window
GL_Context               :: sdl2.GLContext
Event                    :: sdl2.Event
Keycode                  :: sdl2.Keycode
Scancode                 :: sdl2.Scancode
Joystick_ID              :: sdl2.JoystickID
Game_Controller          :: sdl2.GameController
Game_Controller_Button   :: sdl2.GameControllerButton
Game_Controller_Axis     :: sdl2.GameControllerAxis

GL_DESIRED_MAJOR_VERSION :: 4
GL_DESIRED_MINOR_VERSION :: 1

@(private="file") _platform: ^Platform_State

@(private) platform_init :: proc() -> (platform_state: ^Platform_State, ok: bool) #optional_ok {
    profiler_zone("platform_init", PROFILER_COLOR_ENGINE)

    log.infof("Platform (SDL) ---------------------------------------------")
    defer log_ok(ok)

    _platform = tools.mem_named_arena_virtual_bootstrap_new_or_panic(Platform_State, "arena", 1 * mem.Megabyte, "platform")
    context.allocator = _platform.arena.allocator

    error := sdl2.Init({ .VIDEO, .GAMECONTROLLER })
    if error != 0 {
        log.errorf("sdl2.Init error: %v.", error)
        return
    }

    version: sdl2.version
    sdl2.GetVersion(&version)
    log.infof("  SDL version:          %v.%v.%v", version.major, version.minor, version.patch)

    for key in Scancode {
        _platform.inputs.keys[key] = Key_State { }
    }
    for button in Mouse_Button {
        _platform.inputs.mouse_keys[button] = Key_State { }
    }

    return _platform, true
}

@(private) gl_init :: proc() {
    sdl2.GL_SetAttribute(.CONTEXT_PROFILE_MASK, i32(sdl2.GLprofile.CORE))

    gl.load_up_to(GL_DESIRED_MAJOR_VERSION, GL_DESIRED_MINOR_VERSION, proc(ptr: rawptr, name: cstring) {
        (cast(^rawptr)ptr)^ = sdl2.GL_GetProcAddress(name)
    })

    _platform.gl_context = sdl2.GL_CreateContext(_platform.window)
    if _platform.gl_context == nil {
        fmt.panicf("sdl2.GL_CreateContext error: %v.\n", sdl2.GetError())
    }

    p_set_vsync(1)
}

// 0 for immediate updates, 1 for updates synchronized with the vertical retrace, -1 for adaptive vsync
p_set_vsync :: proc(value: c.int) {
    sdl2.GL_SetSwapInterval(value)
}

@(private) open_window :: proc(window_size: Vector2i32) -> rawptr {
    _platform.window = sdl2.CreateWindow("", sdl2.WINDOWPOS_UNDEFINED, sdl2.WINDOWPOS_UNDEFINED, window_size.x, window_size.y, { .SHOWN, .RESIZABLE, .OPENGL })
    if _platform.window == nil {
        fmt.panicf("sdl2.CreateWindow failed.\n")
    }

    _platform.frame_stat.target_fps = f32(get_refresh_rate())

    return _platform
}

@(private) platform_quit :: proc() {
    // sdl2.Quit()
}

@(private) platform_reload :: proc(platform_ptr: ^Platform_State) {
    assert(platform_ptr != nil)
    _platform = platform_ptr
}

@(private) platform_frame_begin :: proc() {
    profiler_frame_mark_start()
    _platform.frame_stat.start = sdl2.GetPerformanceCounter()
    _platform.frame_stat.ctx = profiler_zone_begin(fmt.tprintf("Frame %v", _platform.frame_stat.count))
    profiler_zone("platform_frame_begin")

    {
        _platform.inputs.keyboard_was_used = false
        _platform.inputs.controller_was_used = false
        for key in Scancode {
            (&_platform.inputs.keys[key]).released = false
            (&_platform.inputs.keys[key]).pressed = false
            if _platform.inputs.keys[key].down || _platform.inputs.keys[key].released {
                _platform.inputs.keyboard_was_used = true
            }
        }
        for key in _platform.inputs.mouse_keys {
            (&_platform.inputs.mouse_keys[key]).released = false
            (&_platform.inputs.mouse_keys[key]).pressed = false
        }
        for _, controller_state in _platform.inputs.controllers {
            for key in controller_state.buttons {
                (&controller_state.buttons[key]).released = false
                (&controller_state.buttons[key]).pressed = false
                if controller_state.buttons[key].down || controller_state.buttons[key].released {
                    _platform.inputs.controller_was_used = true
                }
            }
        }
        _platform.inputs.input_text = ""
        _platform.inputs.mouse_wheel.x = 0
        _platform.inputs.mouse_wheel.y = 0
        _platform.inputs.mouse_moved = false
    }

    _platform.window_resized = false

    {
        profiler_zone("poll_events")
        e: Event
        for sdl2.PollEvent(&e) {
            ui_process_event(&e)

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
                    _platform.inputs.input_text = string(cstring(&e.text.text[0]))
                }

                case .MOUSEMOTION: {
                    _platform.inputs.mouse_position.x = e.motion.x
                    _platform.inputs.mouse_position.y = e.motion.y
                    _platform.inputs.mouse_moved = true
                }
                case .MOUSEBUTTONDOWN, .MOUSEBUTTONUP: {
                    key := &_platform.inputs.mouse_keys[cast(Mouse_Button) e.button.button]
                    key.down = e.type == .MOUSEBUTTONDOWN
                    key.released = e.type == .MOUSEBUTTONUP
                    key.pressed = e.type == .MOUSEBUTTONDOWN
                }
                case .MOUSEWHEEL: {
                    _platform.inputs.mouse_wheel.x = e.wheel.x
                    _platform.inputs.mouse_wheel.y = e.wheel.y
                }

                case .KEYDOWN, .KEYUP: {
                    key := &_platform.inputs.keys[e.key.keysym.scancode]
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
                                _platform.inputs.controllers[joystick_id] = { controller, buttons, axes }
                                controller_name := controller_get_name(controller)
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

                    controller_state, controller_found := _platform.inputs.controllers[joystick_id]
                    if controller_found {
                        controller_name := controller_get_name(controller_state.controller)
                        log.infof("Controller removed: %v (%v)", controller_name, joystick_id)

                        sdl2.GameControllerClose(controller_state.controller)
                        delete_key(&_platform.inputs.controllers, joystick_id)
                    }
                }

                case .CONTROLLERBUTTONDOWN, .CONTROLLERBUTTONUP: {
                    controller_button_event := (^sdl2.ControllerButtonEvent)(&e)^
                    joystick_id := controller_button_event.which
                    button := cast(Game_Controller_Button) controller_button_event.button

                    controller_state, controller_found := _platform.inputs.controllers[joystick_id]
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

                    controller_state, controller_found := _platform.inputs.controllers[joystick_id]
                    if controller_found {
                        axis := &controller_state.axes[axis]
                        axis.value = controller_axis_event.value
                    }
                }
            }
        }
    }
}

@(private) platform_frame_end :: proc() {
    {
        profiler_zone("frame_end", PROFILER_COLOR_ENGINE)

        file_watch_update()

        {
            profiler_zone("swap", PROFILER_COLOR_ENGINE)
            _platform.frame_stat.gpu_start = sdl2.GetPerformanceCounter()
            sdl2.GL_SwapWindow(_platform.window)
        }

        update_frame_stat(&_platform.frame_stat)
        if _platform.frame_stat.sleep_time > 0 {
            profiler_zone("delay", PROFILER_COLOR_ENGINE)
            sdl2.Delay(u32(_platform.frame_stat.sleep_time))
        }

        free_all(context.temp_allocator)
        _platform.frame_stat.count += 1
    }

    profiler_zone_end(_platform.frame_stat.ctx)
    profiler_frame_mark_end()

}

get_ticks :: proc() -> u32 {
    return sdl2.GetTicks()
}

get_pixel_density :: proc() -> f32 {
    window_size := get_window_size()
    output_width, output_height: i32
    sdl2.GL_GetDrawableSize(_platform.window, &output_width, &output_height)
    if output_width == 0 || output_height == 0 {
        log.errorf("sdl2.GL_GetDrawableSize error: %v.", sdl2.GetError())
        return 1
    }
    return f32(output_width) / f32(window_size.x)
}

get_refresh_rate :: proc() -> (refresh_rate: i32 = 60) {
    assert(_platform.window != nil, "No window opened.")
    display_mode: sdl2.DisplayMode
    display_index := sdl2.GetWindowDisplayIndex(_platform.window)
    if sdl2.GetCurrentDisplayMode(display_index, &display_mode) == 0 && display_mode.refresh_rate > 0 {
        return display_mode.refresh_rate
    }
    return
}

set_target_fps :: proc(target_fps: int) {
    _platform.frame_stat.target_fps = f32(target_fps)
}
get_frame_stat :: proc() -> Frame_Stat {
    return _platform.frame_stat
}

should_quit :: proc() -> bool {
    return _platform.quit_requested
}

window_was_resized :: proc() -> bool {
    return _platform.window_resized
}

mouse_moved :: proc() -> bool {
    return _platform.inputs.mouse_moved
}
mouse_button_is_down :: proc(button: Mouse_Button) -> bool {
    return _platform.inputs.mouse_keys[button].down
}
mouse_get_position :: proc() -> Vector2i32 {
    return _platform.inputs.mouse_position
}
get_inputs :: proc() -> ^Inputs {
    return &_platform.inputs
}

controller_get_name :: proc(controller: ^Game_Controller) -> string {
    return string(sdl2.GameControllerName(controller))
}
controller_get_by_player_index :: proc(player_index: int) -> (controller_state: ^Controller_State, found: bool) {
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
    controller_state, controller_found = &_platform.inputs.controllers[joystick_id]
    if controller_found != true {
        return
    }
    return controller_state, true
}

set_window_title :: proc(title: string, args: ..any) {
    sdl2.SetWindowTitle(_platform.window, strings.clone_to_cstring(fmt.tprintf(title, ..args), context.temp_allocator))
}

set_window_size :: proc (window_size: Vector2i32) {
    sdl2.SetWindowSize(_platform.window, window_size.x, window_size.y)
}

get_window_size :: proc () -> Vector2f32 {
    window := _platform.window
    window_width: i32
    window_height: i32
    sdl2.GetWindowSize(window, &window_width, &window_height)
    if window_width == 0 || window_height == 0 {
        log.errorf("sdl2.GetWindowSize error: %v.", sdl2.GetError())
        return { 0, 0 }
    }
    return { f32(window_width), f32(window_height) }
}

platform_load_image :: proc(filepath: string, width, height, channels_in_file: ^i32, desired_channels: i32 = 0) -> [^]byte {
    // stb_image.set_flip_vertically_on_load(1)
    return stb_image.load(strings.clone_to_cstring(filepath, context.temp_allocator), width, height, channels_in_file, desired_channels)
}

@(private) update_frame_stat :: proc(stat: ^Frame_Stat) {
    frame_end := sdl2.GetPerformanceCounter()
    cpu_time := f32(frame_end - stat.start) * 1_000 / f32(sdl2.GetPerformanceFrequency())
    gpu_time := f32(frame_end - stat.gpu_start) * 1_000 / f32(sdl2.GetPerformanceFrequency())
    target_frame_time := 1_000 / stat.target_fps
    stat.sleep_time = math.max(target_frame_time - cpu_time, 0)
    stat.fps = 1_000 / cpu_time
    stat.cpu_time = cpu_time
    stat.gpu_time = gpu_time
    stat.delta_time = stat.cpu_time + stat.sleep_time
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


ui_widget_frame_stat :: proc() {
    frame_stat := _platform.frame_stat
    if ui_tree_node("frame_stat", { .DefaultOpen }) {
        ui_text("target_fps:    ")
        ui_same_line()
        if ui_slider_float("###target_fps", &frame_stat.target_fps, 1, 240) {
            set_target_fps(int(frame_stat.target_fps))
        }

        ui_text("fps:           %3.0f", frame_stat.fps)
        ui_text("sleep_time:    %3.0f", frame_stat.sleep_time)
        ui_text("delta_time:    %3.0f", frame_stat.delta_time)
        @(static) fps_plot := Statistic_Plot {}; ui_set_next_item_width(400); ui_statistic_plots(&fps_plot, frame_stat.fps, "fps", min = 0, max = 5_000)
        // @(static) delta_time_plot := Statistic_Plot {}; imgui.SetNextItemWidth(400); ui_statistic_plots(&delta_time_plot, frame_stat.delta_time, "delta_time", min = 0, max = 100)
    }
}

ui_widget_mouse :: proc() {
    if ui_tree_node("Mouse", { }) {
        ui_text("mouse_position: %v", mouse_get_position())

        Row :: struct { name: Mouse_Button, value: ^Key_State }
        rows := []Row {
            { .Left, &_platform.inputs.mouse_keys[.Left] },
            { .Middle, &_platform.inputs.mouse_keys[.Middle] },
            { .Right, &_platform.inputs.mouse_keys[.Right] },
        }
        columns := []string { "key", "down", "up", "pressed", "released" }
        if ui_table(columns) {
            for row in rows {
                ui_table_next_row()
                for column, column_index in columns {
                    ui_table_set_column_index(i32(column_index))
                    switch column {
                        case "key": ui_text("%v", row.name)
                        case "down": ui_text("%v", row.value.down)
                        case "up": ui_text("%v", !row.value.down)
                        case "pressed": ui_text("%v", row.value.pressed)
                        case "released": ui_text("%v", row.value.released)
                    }
                }
            }
        }
    }
}

ui_widget_controllers :: proc() {
    if ui_tree_node(fmt.tprintf("Controllers (%v)", len(_platform.inputs.controllers))) {
        for joystick_id, controller_state in _platform.inputs.controllers {
            controller_name := controller_get_name(controller_state.controller)
            if ui_tree_node(fmt.tprintf("%v (%v)", controller_name, joystick_id), { .DefaultOpen }) {
                {
                    Row :: struct { name: Game_Controller_Axis, value: ^Axis_State }
                    rows := []Row {
                        // .INVALID = -1,
                        { .LEFTX, &controller_state.axes[.LEFTX] },
                        { .LEFTY, &controller_state.axes[.LEFTY] },
                        { .RIGHTX, &controller_state.axes[.RIGHTX] },
                        { .RIGHTY, &controller_state.axes[.RIGHTY] },
                        { .TRIGGERLEFT, &controller_state.axes[.TRIGGERLEFT] },
                        { .TRIGGERRIGHT, &controller_state.axes[.TRIGGERRIGHT] },
                        // .MAX,
                    }
                    columns := []string { "axis", "value" }
                    if ui_table(columns) {
                        for row in rows {
                            ui_table_next_row()
                            for column, column_index in columns {
                                ui_table_set_column_index(i32(column_index))
                                switch column {
                                    case "axis": ui_text("%v", row.name)
                                    case "value": ui_text("%v", row.value)
                                }
                            }
                        }
                    }
                }
                {
                    Row :: struct { name: Game_Controller_Button, value: ^Key_State }
                    rows := []Row {
                        { .A, &controller_state.buttons[.A] },
                        { .B, &controller_state.buttons[.B] },
                        { .X, &controller_state.buttons[.X] },
                        { .Y, &controller_state.buttons[.Y] },
                        { .BACK, &controller_state.buttons[.BACK] },
                        // .GUIDE,
                        { .START, &controller_state.buttons[.START] },
                        { .LEFTSTICK, &controller_state.buttons[.LEFTSTICK] },
                        { .RIGHTSTICK, &controller_state.buttons[.RIGHTSTICK] },
                        { .LEFTSHOULDER, &controller_state.buttons[.LEFTSHOULDER] },
                        { .RIGHTSHOULDER, &controller_state.buttons[.RIGHTSHOULDER] },
                        { .DPAD_UP, &controller_state.buttons[.DPAD_UP] },
                        { .DPAD_DOWN, &controller_state.buttons[.DPAD_DOWN] },
                        { .DPAD_LEFT, &controller_state.buttons[.DPAD_LEFT] },
                        { .DPAD_RIGHT, &controller_state.buttons[.DPAD_RIGHT] },
                        // .MISC1,
                        // .PADDLE1,
                        // .PADDLE2,
                        // .PADDLE3,
                        // .PADDLE4,
                        // .TOUCHPAD,
                        // .MAX,
                    }
                    columns := []string { "key", "down", "up", "pressed", "released" }
                    if ui_table(columns) {
                        for row in rows {
                            ui_table_next_row()
                            for column, column_index in columns {
                                ui_table_set_column_index(i32(column_index))
                                switch column {
                                    case "key": ui_text("%v", row.name)
                                    case "down": ui_text("%v", row.value.down)
                                    case "up": ui_text("%v", !row.value.down)
                                    case "pressed": ui_text("%v", row.value.pressed)
                                    case "released": ui_text("%v", row.value.released)
                                }
                            }
                        }
                    }
                }
            }
        }
        if len(_platform.inputs.controllers) == 0 {
            ui_text("No controllers detected.")
        }
    }
}

ui_widget_keyboard :: proc() {
    if ui_tree_node("Keyboard", { }) {
        Row :: struct { name: Scancode, value: ^Key_State }
        rows := []Row {
            { .UP, &_platform.inputs.keys[.UP] },
            { .DOWN, &_platform.inputs.keys[.DOWN] },
            { .LEFT, &_platform.inputs.keys[.LEFT] },
            { .RIGHT, &_platform.inputs.keys[.RIGHT] },
            { .A, &_platform.inputs.keys[.A] },
            { .D, &_platform.inputs.keys[.D] },
            { .W, &_platform.inputs.keys[.W] },
            { .S, &_platform.inputs.keys[.S] },
            { .LSHIFT, &_platform.inputs.keys[.LSHIFT] },
            { .LCTRL, &_platform.inputs.keys[.LCTRL] },
            { .LALT, &_platform.inputs.keys[.LALT] },
            { .BACKSPACE, &_platform.inputs.keys[.BACKSPACE] },
            { .DELETE, &_platform.inputs.keys[.DELETE] },
            { .RETURN, &_platform.inputs.keys[.RETURN] },
            { .ESCAPE, &_platform.inputs.keys[.ESCAPE] },
            { .GRAVE, &_platform.inputs.keys[.GRAVE] },
            { .F1, &_platform.inputs.keys[.F1] },
            { .F2, &_platform.inputs.keys[.F2] },
            { .F3, &_platform.inputs.keys[.F3] },
            { .F4, &_platform.inputs.keys[.F4] },
            { .F5, &_platform.inputs.keys[.F5] },
            { .F6, &_platform.inputs.keys[.F6] },
            { .F7, &_platform.inputs.keys[.F7] },
            { .F8, &_platform.inputs.keys[.F8] },
            { .F9, &_platform.inputs.keys[.F9] },
            { .F10, &_platform.inputs.keys[.F10] },
            { .F11, &_platform.inputs.keys[.F11] },
            { .F12, &_platform.inputs.keys[.F12] },
        }
        columns := []string { "key", "down", "up", "pressed", "released" }
        if ui_table(columns) {
            for row in rows {
                ui_table_next_row()
                for column, column_index in columns {
                    ui_table_set_column_index(i32(column_index))
                    switch column {
                        case "key": ui_text("%v", row.name)
                        case "down": ui_text("%v", row.value.down)
                        case "up": ui_text("%v", !row.value.down)
                        case "pressed": ui_text("%v", row.value.pressed)
                        case "released": ui_text("%v", row.value.released)
                    }
                }
            }
        }
    }
}
