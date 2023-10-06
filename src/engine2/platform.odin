package engine2

import "core:fmt"
import "core:log"
import "core:mem"
import "vendor:sdl2"
import tracy "../odin-tracy"

Window      :: sdl2.Window
Version     :: sdl2.version
Keycode     :: sdl2.Keycode
Scancode    :: sdl2.Scancode

Platform :: struct {
    window:                 ^Window,
    version:                Version,
    allocator:              mem.Allocator,
    tracking_allocator:     mem.Tracking_Allocator,
    logger:                 log.Logger,
    quit_requested:         bool,
    window_resized:         bool,
    frame_start:            u64,
    frame_end:              u64,
    keys:                   map[Scancode]Key_State,
}

Key_State :: struct {
    down:       bool, // The key is down
    pressed:    bool, // The key was pressed this frame
    released:   bool, // The key was released this frame
}

@(private="package")
p: ^Platform

platform_init :: proc(window_size: Vector2i32) -> (_p: ^Platform, ok: bool) {
    p = new(Platform)
    mem.tracking_allocator_init(&p.tracking_allocator, context.allocator)
    p.allocator = mem.tracking_allocator(&p.tracking_allocator)
    p.allocator = tracy.MakeProfiledAllocator(
        self              = &tracy.ProfiledAllocatorData {},
        callstack_size    = 5,
        backing_allocator = context.allocator,
        secure            = true,
    )
    p.logger = log.create_console_logger(.Debug, { .Level, .Terminal_Color })

    tracy.SetThreadName("main")

    error := sdl2.Init({ .VIDEO, .AUDIO, .GAMECONTROLLER })
    if error != 0 {
        log.errorf("sdl2.Init error: %v.", error)
        return
    }

    sdl2.GetVersion(&p.version)
    log.infof("Platform ---------------------------------------------------")
    log.infof("  SDL version: %v.%v.%v", p.version.major, p.version.minor, p.version.patch)

    p.keys = make(map[Scancode]Key_State, sdl2.NUM_SCANCODES)
    for key in Scancode {
        p.keys[key] = Key_State { }
    }
    // p.mouse_keys[BUTTON_LEFT] = Key_State { }
    // p.mouse_keys[BUTTON_MIDDLE] = Key_State { }
    // p.mouse_keys[BUTTON_RIGHT] = Key_State { }

    p.window = sdl2.CreateWindow(
        nil,
        sdl2.WINDOWPOS_UNDEFINED, sdl2.WINDOWPOS_UNDEFINED,
        window_size.x, window_size.y, { .SHOWN, .RESIZABLE, .ALLOW_HIGHDPI, .OPENGL },
    )
    if p.window == nil {
        log.errorf("sdl2.CreateWindow error: %v.", sdl2.GetError())
        return
    }
    log.infof("  Window created: %v | %p", window_size, p.window)

    return p, ok
}

platform_deinit :: proc() {
    // defer free(context.logger.data)
    delete(p.keys)
    free(p)

    if len(p.tracking_allocator.allocation_map) > 0 {
        fmt.eprintf("=== %v allocations not freed: ===\n", len(p.tracking_allocator.allocation_map))
        for _, entry in p.tracking_allocator.allocation_map {
            fmt.eprintf("- %v bytes @ %v\n", entry.size, entry.location)
        }
    } else if len(p.tracking_allocator.bad_free_array) > 0 {
        fmt.eprintf("=== %v incorrect frees: ===\n", len(p.tracking_allocator.bad_free_array))
        for entry in p.tracking_allocator.bad_free_array {
            fmt.eprintf("- %p @ %v\n", entry.memory, entry.location)
        }
    } else {
        fmt.printf("No issues detected in tracking_allocator.\n")
    }
    mem.tracking_allocator_destroy(&p.tracking_allocator)
}

@(deferred_none=_platform_frame_end)
platform_frame :: proc() -> bool {
    context.allocator = p.allocator
    _platform_frame_begin()
    return true
}

_platform_frame_begin :: proc() {
    tracy.FrameMarkStart(nil)
    p.frame_start = sdl2.GetPerformanceCounter()

    _platform_process_events()
    // renderer_begin_ui()
    // renderer_render_begin()
}

@(private="file")
_platform_frame_end :: proc() {
    // renderer_render_end()

    // platform_reset_inputs()
    {
        for key in Scancode {
            (&p.keys[key]).released = false
            (&p.keys[key]).pressed = false
        }
        // for key in p.mouse_keys {
        //     (&p.mouse_keys[key]).released = false
        //     (&p.mouse_keys[key]).pressed = false
        // }
        // for _, controller_state in p.controllers {
        //     for key in controller_state.buttons {
        //         (&controller_state.buttons[key]).released = false
        //         (&controller_state.buttons[key]).pressed = false
        //     }
        // }
        // p.input_text = ""
        // p.mouse_wheel.x = 0
        // p.mouse_wheel.y = 0
        // p.mouse_moved = false
    }
    // platform_reset_events()

    // All timings here are in milliseconds
    performance_frequency := sdl2.GetPerformanceFrequency()
    frame_budget : f32 = 1_000 / f32(platform_get_refresh_rate(p.window))
    // TODO: Pretty sure this CPU/GPU calculations are wrong
    cpu_duration := f32(sdl2.GetPerformanceCounter() - p.frame_start) * 1_000 / f32(performance_frequency)
    // gpu_duration := f32(_e.renderer.draw_duration) / 1_000_000
    gpu_duration : f32 = 0
    frame_duration := cpu_duration + gpu_duration
    frame_delay := max(0, frame_budget - frame_duration)

    // FIXME: not sure if sdl2.Delay() is the best way here
    // FIXME: we don't want to freeze since we still want to do some things as fast as possible (ie: inputs)
    {
        tracy.ZoneN("delay")
        sdl2.Delay(u32(frame_delay))
    }

    // p.locked_fps = i32(1_000 / (frame_duration + frame_delay))
    // p.actual_fps = i32(1_000 / frame_duration)
    // p.frame_delay = frame_delay
    // p.frame_duration = frame_duration
    // p.frame_end = frame_end
    // p.delta_time = f32(sdl2.GetPerformanceCounter() - p.frame_start) * 1000 / performance_frequency
    // p.frame_count += 1

    delta_time := f32(sdl2.GetPerformanceCounter() - p.frame_start) * 1000 / f32(performance_frequency)
    // log.debugf("cpu %.5fms | gpu %.5fms | delta_time %v", cpu_duration, gpu_duration, delta_time)

    tracy.FrameMarkEnd(nil)
}

platform_get_refresh_rate :: proc(window: ^Window) -> i32 {
    refresh_rate: i32 = 60
    display_mode: sdl2.DisplayMode
    display_index := sdl2.GetWindowDisplayIndex(window)
    if sdl2.GetCurrentDisplayMode(display_index, &display_mode) == 0 && display_mode.refresh_rate > 0 {
        refresh_rate = display_mode.refresh_rate
    }
    return refresh_rate
}

@(private="file")
_platform_process_events :: proc() {
    e: sdl2.Event
    for sdl2.PollEvent(&e) {
        // rendererprocess_events(&e)

        #partial switch e.type {
            case .QUIT:
                p.quit_requested = true

            case .WINDOWEVENT: {
                window_event := (^sdl2.WindowEvent)(&e)^
                #partial switch window_event.event {
                    case .RESIZED: {
                        p.window_resized = true
                    }
                    case .SHOWN: {
                        p.window_resized = true
                    }
                    // case: {
                    //     log.debugf("window_event: %v", window_event)
                    // }
                }
            }

            // case .TEXTINPUT: {
            //     p.input_text = string(cstring(&e.text.text[0]))
            // }

            // case .MOUSEMOTION: {
            //     p.mouseposition.x = e.motion.x
            //     p.mouseposition.y = e.motion.y
            //     p.mouse_moved = true
            // }
            // case .MOUSEBUTTONDOWN, .MOUSEBUTTONUP: {
            //     key := &p.mouse_keys[i32(e.button.button)]
            //     key.down = e.type == .MOUSEBUTTONDOWN
            //     key.released = e.type == .MOUSEBUTTONUP
            //     key.pressed = e.type == .MOUSEBUTTONDOWN
            // }
            // case .MOUSEWHEEL: {
            //     p.mouse_wheel.x = e.wheel.x
            //     p.mouse_wheel.y = e.wheel.y
            // }

            case .KEYDOWN, .KEYUP: {
                key := &p.keys[e.key.keysym.scancode]
                key.down = e.type == .KEYDOWN
                key.released = e.type == .KEYUP
                key.pressed = e.type == .KEYDOWN
            }

            // case .CONTROLLERDEVICEADDED: {
            //     controller_event := (^sdl2.ControllerDeviceEvent)(&e)^
            //     joystick_index := controller_event.which

            //     if sdl2.IsGameController(controller_event.which) {
            //         controller := sdl2.GameControllerOpen(controller_event.which)
            //         if controller != nil {
            //             joystick := sdl2.GameControllerGetJoystick(controller)

            //             joystick_id := sdl2.JoystickInstanceID(joystick)
            //             if joystick_id < 0 {
            //                 log.error("JoystickInstanceID error")
            //             } else {
            //                 buttons := map[GameControllerButton]Key_State {}
            //                 for button in GameControllerButton {
            //                     buttons[button] = Key_State {}
            //                 }
            //                 axes := map[GameControllerAxis]Axis_State {}
            //                 for axis in GameControllerAxis {
            //                     axes[axis] = Axis_State {}
            //                 }
            //                 p.controllers[joystick_id] = { controller, buttons, axes }
            //                 controller_name := platform_get_controller_name(controller)
            //                 log.infof("Controller added  : %v (%v)", controller_name, joystick_id)
            //             }
            //         } else {
            //             log.error("GameControllerOpen error")
            //         }
            //     } else {
            //         log.error("IsGameController error")
            //     }
            // }

            // case .CONTROLLERDEVICEREMOVED: {
            //     controller_event := (^sdl2.ControllerDeviceEvent)(&e)^
            //     joystick_id := JoystickID(controller_event.which)

            //     controller_state, controller_found := p.controllers[joystick_id]
            //     if controller_found {
            //         controller_name := platform_get_controller_name(controller_state.controller)
            //         log.infof("Controller removed: %v (%v)", controller_name, joystick_id)

            //         sdl2.GameControllerClose(controller_state.controller)
            //         delete_key(&p.controllers, joystick_id)
            //     }
            // }

            // case .CONTROLLERBUTTONDOWN, .CONTROLLERBUTTONUP: {
            //     controller_button_event := (^sdl2.ControllerButtonEvent)(&e)^
            //     joystick_id := controller_button_event.which
            //     button := GameControllerButton(controller_button_event.button)

            //     controller_state, controller_found := p.controllers[joystick_id]
            //     if controller_found {
            //         key := &controller_state.buttons[button]
            //         key.down = controller_button_event.state == sdl2.PRESSED
            //         key.released = controller_button_event.state == sdl2.RELEASED
            //         key.pressed = controller_button_event.state == sdl2.PRESSED
            //     }
            // }

            // case .CONTROLLERAXISMOTION: {
            //     controller_axis_event := (^sdl2.ControllerAxisEvent)(&e)^
            //     joystick_id := controller_axis_event.which
            //     axis := GameControllerAxis(controller_axis_event.axis)

            //     controller_state, controller_found := p.controllers[joystick_id]
            //     if controller_found {
            //         axis := &controller_state.axes[axis]
            //         axis.value = controller_axis_event.value
            //     }
            // }
        }
    }
}
