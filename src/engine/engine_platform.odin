package engine

import "core:c"
import "core:log"
import "core:math"
import "core:mem"
import "core:os"
import "core:slice"
import "core:strings"
import "vendor:sdl2"
import "vendor:stb/image"

Surface              :: sdl2.Surface;
Keycode              :: sdl2.Keycode;
Scancode             :: sdl2.Scancode;
Window               :: sdl2.Window;
JoystickID           :: sdl2.JoystickID;
GameController       :: sdl2.GameController;
GameControllerButton :: sdl2.GameControllerButton;
GameControllerAxis   :: sdl2.GameControllerAxis;

BUTTON          :: sdl2.BUTTON;
BUTTON_LEFT     :: sdl2.BUTTON_LEFT;
BUTTON_MIDDLE   :: sdl2.BUTTON_MIDDLE;
BUTTON_RIGHT    :: sdl2.BUTTON_RIGHT;

APP_BASE_ADDRESS        :: 2 * mem.Terabyte;
APP_ARENA_SIZE          :: 8 * mem.Megabyte;
TIME_HISTORY_COUNT      :: 4;
SNAP_FREQUENCY_COUNT    :: 5;

Platform_State :: struct {
    arena:                  ^mem.Arena,
    allocator:              mem.Allocator,
    temp_allocator:         mem.Allocator,
    code_reload_requested:  bool,
    window:                 ^Window,
    quit:                   bool,
    window_resized:         bool,

    keys:                   map[Scancode]Key_State,
    mouse_keys:             map[i32]Key_State,
    mouse_position:         Vector2i,
    input_text:             string,
    input_scroll:           Vector2i,
    controllers:            map[JoystickID]Controller_State,

    unlock_framerate:       bool,
    snap_frequencies:       [SNAP_FREQUENCY_COUNT]u64,
    time_averager:          [TIME_HISTORY_COUNT]u64,
    resync:                 bool,
    update_multiplicity:    int,
    update_rate:            int,
    desired_frametime:      u64,
    vsync_maxerror:         u64,
    averager_residual:      u64,
    prev_frame_time:        u64,
    frame_accumulator:      u64,
    fixed_deltatime:        f64,
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

Update_Proc :: #type proc(delta_time: f64, app: ^App)

platform_init :: proc(allocator: mem.Allocator, temp_allocator: mem.Allocator) -> (state: ^Platform_State, ok: bool) {
    context.allocator = allocator;

    state = new(Platform_State);
    state.allocator = allocator;
    state.temp_allocator = temp_allocator;
    state.arena = cast(^mem.Arena)allocator.data;

    // set_memory_functions_default();

    if error := sdl2.Init({ .VIDEO, .AUDIO, .GAMECONTROLLER }); error != 0 {
        log.errorf("sdl2.Init error: %v.", error);
        return;
    }

    for key in Scancode {
        state.keys[key] = Key_State { };
    }
    state.mouse_keys[BUTTON_LEFT] = Key_State { };
    state.mouse_keys[BUTTON_MIDDLE] = Key_State { };
    state.mouse_keys[BUTTON_RIGHT] = Key_State { };

    // Framerate preparations (source: http://web.archive.org/web/20221205112541/https://github.com/TylerGlaiel/FrameTimingControl)
    {
        state.update_rate = 60;
        state.update_multiplicity = 1;

        // compute how many ticks one update should be
        state.fixed_deltatime = f64(1.0) / f64(state.update_rate);
        state.desired_frametime = sdl2.GetPerformanceFrequency() / u64(state.update_rate);

        // these are to snap deltaTime to vsync values if it's close enough
        state.vsync_maxerror = sdl2.GetPerformanceFrequency() / 5000;
        time_60hz : u64 = sdl2.GetPerformanceFrequency() / 60; // since this is about snapping to common vsync values
        state.snap_frequencies = {
            time_60hz,           // 60fps
            time_60hz * 2,       // 30fps
            time_60hz * 3,       // 20fps
            time_60hz * 4,       // 15fps
            (time_60hz + 1) / 2, // 120fps //120hz, 240hz, or higher need to round up, so that adding 120hz twice guaranteed is at least the same as adding time_60hz once
        };

        state.time_averager = { state.desired_frametime, state.desired_frametime, state.desired_frametime, state.desired_frametime };
        state.averager_residual = 0;

        state.resync = true;
        state.prev_frame_time = sdl2.GetPerformanceCounter();
        state.frame_accumulator = 0;
    }

    ok = true;
    return;
}

open_window :: proc(platform_state: ^Platform_State, title: string, size: Vector2i) -> (ok: bool) {
    context.allocator = platform_state.allocator;

    platform_state.window = sdl2.CreateWindow(
        strings.clone_to_cstring(title),
        sdl2.WINDOWPOS_UNDEFINED, sdl2.WINDOWPOS_UNDEFINED,
        size.x, size.y, { .SHOWN, .RESIZABLE, .ALLOW_HIGHDPI },
    );

    if platform_state.window == nil {
        log.errorf("sdl2.CreateWindow error: %v.", sdl2.GetError());
        return;
    }

    ok = true;
    return;
}
close_window :: proc(platform_state: ^Platform_State) {
    sdl2.DestroyWindow(platform_state.window);
}

process_events :: proc(platform_state: ^Platform_State) {
    profiler_zone("process_events", 0x005500);

    context.allocator = platform_state.allocator;
    e: sdl2.Event;

    for sdl2.PollEvent(&e) {
        #partial switch e.type {
            case .QUIT:
                platform_state.quit = true;

            case .WINDOWEVENT: {
                window_event := (^sdl2.WindowEvent)(&e)^;
                #partial switch window_event.event {
                    case .RESIZED: {
                        platform_state.window_resized = true;
                    }
                    case .SHOWN: {
                        platform_state.window_resized = true;
                    }
                    // case: {
                    //     log.debugf("window_event: %v", window_event);
                    // }
                }
            }

            case .TEXTINPUT: {
                platform_state.input_text = string(cstring(&e.text.text[0]));
            }

            case .MOUSEMOTION: {
                platform_state.mouse_position.x = e.motion.x;
                platform_state.mouse_position.y = e.motion.y;
            }
            case .MOUSEBUTTONUP: {
                key := &platform_state.mouse_keys[i32(e.button.button)];
                key.down = false;
                key.pressed = false;
                key.released = true;
            }
            case .MOUSEBUTTONDOWN: {
                key := &platform_state.mouse_keys[i32(e.button.button)];
                key.down = true;
                key.pressed = true;
                key.released = false;
            }
            case .MOUSEWHEEL: {
                platform_state.input_scroll.x = e.wheel.x;
                platform_state.input_scroll.y = e.wheel.y;
            }

            case .KEYDOWN, .KEYUP: {
                key := &platform_state.keys[e.key.keysym.scancode];
                key.down = e.type == .KEYDOWN;
                key.released = e.type == .KEYUP;
                key.pressed = e.type == .KEYDOWN;
            }

            case .CONTROLLERDEVICEADDED: {
                controller_event := (^sdl2.ControllerDeviceEvent)(&e)^;
                joystick_index := controller_event.which;

                if sdl2.IsGameController(controller_event.which) {
                    controller := sdl2.GameControllerOpen(controller_event.which);
                    if controller != nil {
                        joystick := sdl2.GameControllerGetJoystick(controller);

                        joystick_id := sdl2.JoystickInstanceID(joystick);
                        if joystick_id < 0 {
                            log.error("JoystickInstanceID error");
                        } else {
                            buttons := map[GameControllerButton]Key_State {};
                            for button in GameControllerButton {
                                buttons[button] = Key_State {};
                            }
                            axes := map[GameControllerAxis]Axis_State {};
                            for axis in GameControllerAxis {
                                axes[axis] = Axis_State {};
                            }
                            platform_state.controllers[joystick_id] = { controller, buttons, axes };
                            controller_name := get_controller_name(controller);
                            log.infof("Controller added: %v (%v)", controller_name, joystick_id);
                        }
                    } else {
                        log.error("GameControllerOpen error");
                    }
                } else {
                    log.error("IsGameController error");
                }
            }

            case .CONTROLLERDEVICEREMOVED: {
                controller_event := (^sdl2.ControllerDeviceEvent)(&e)^;
                joystick_id := JoystickID(controller_event.which);

                controller_state, controller_found := platform_state.controllers[joystick_id];
                if controller_found {
                    controller_name := get_controller_name(controller_state.controller);
                    log.infof("Controller removed: %v (%v)", controller_name, joystick_id);

                    sdl2.GameControllerClose(controller_state.controller);
                    delete_key(&platform_state.controllers, joystick_id);
                }
            }

            case .CONTROLLERBUTTONDOWN, .CONTROLLERBUTTONUP: {
                controller_button_event := (^sdl2.ControllerButtonEvent)(&e)^;
                joystick_id := JoystickID(controller_button_event.which);
                button := GameControllerButton(controller_button_event.button);

                controller_state, controller_found := platform_state.controllers[joystick_id];
                if controller_found {
                    key := &controller_state.buttons[button];
                    key.down = controller_button_event.state == sdl2.PRESSED;
                    key.released = controller_button_event.state == sdl2.RELEASED;
                    key.pressed = controller_button_event.state == sdl2.PRESSED;
                }
            }

            case .CONTROLLERAXISMOTION: {
                controller_axis_event := (^sdl2.ControllerAxisEvent)(&e)^;
                joystick_id := JoystickID(controller_axis_event.which);
                axis := GameControllerAxis(controller_axis_event.axis);

                controller_state, controller_found := platform_state.controllers[joystick_id];
                if controller_found {
                    axis := &controller_state.axes[axis];
                    axis.value = controller_axis_event.value;
                }
            }
        }
    }
}

get_controller_name :: proc(controller: ^GameController) -> string {
    return string(sdl2.GameControllerName(controller));
}

get_controller_from_player_index :: proc(platform_state: ^Platform_State, player_index: int) -> (controller_state: ^Controller_State, found: bool) {
    controller := sdl2.GameControllerFromPlayerIndex(c.int(player_index));
    if controller == nil {
        return;
    }
    joystick := sdl2.GameControllerGetJoystick(controller);
    if joystick == nil {
        return;
    }
    joystick_id := sdl2.JoystickInstanceID(joystick);
    if joystick_id < 0 {
        return;
    }
    controller_found: bool;
    controller_state, controller_found = &platform_state.controllers[joystick_id];
    if controller_found != true {
        return;
    }
    return controller_state, true;
}

contains_os_args :: proc(value: string) -> bool {
    return slice.contains(os.args, value);
}

load_surface_from_image_file :: proc(platform_state: ^Platform_State, image_path: string) -> (surface: ^Surface, ok: bool) {
    context.allocator = platform_state.allocator;

    path := strings.clone_to_cstring(image_path);
    defer delete(path);

    if strings.has_suffix(image_path, ".bmp") {
        surface = sdl2.LoadBMP(path);
    } else {
        width, height, channels_in_file: i32;
        data := image.load(path, &width, &height, &channels_in_file, 0);
        // defer image.image_free(data);

        // Convert into an SDL2 Surface.
        rmask := u32(0x000000ff);
        gmask := u32(0x0000ff00);
        bmask := u32(0x00ff0000);
        amask := u32(0xff000000) if channels_in_file == 4 else u32(0x0);
        pitch := ((width * channels_in_file) + 3) & ~i32(3);
        depth := channels_in_file * 8;

        surface = sdl2.CreateRGBSurfaceFrom(
            data,
            width, height, depth, pitch,
            rmask, gmask, bmask, amask,
        );
    }


    if surface == nil {
        log.errorf("Couldn't load image: %v.", image_path);
        return;
    }

    ok = true;
    return;
}

free_surface :: proc(surface: ^Surface) {
    sdl2.FreeSurface(surface);
}

get_window_size :: proc (window: ^Window) -> Vector2i {
    window_width : i32 = 0;
    window_height : i32 = 0;
    sdl2.GetWindowSize(window, &window_width, &window_height);
    return { window_width, window_height };
}

calculate_delta_time :: proc(platform_state: ^Platform_State) -> u64 {
    profiler_zone("calculate_delta_time", 0x005500);
    // frame timer
    current_frame_time : u64 = sdl2.GetPerformanceCounter();
    delta_time : u64 = current_frame_time - platform_state.prev_frame_time;
    platform_state.prev_frame_time = current_frame_time;

    // handle unexpected timer anomalies (overflow, extra slow frames, etc)
    if delta_time > platform_state.desired_frametime * 8 { // ignore extra-slow frames
        delta_time = platform_state.desired_frametime;
    }
    if delta_time < 0 {
        delta_time = 0;
    }

    // vsync time snapping
    for snap in platform_state.snap_frequencies {
        if math.abs(delta_time - snap) < platform_state.vsync_maxerror {
            delta_time = snap;
            break;
        }
    }

    // delta time averaging
    for i := 0; i < TIME_HISTORY_COUNT - 1; i += 1 {
        platform_state.time_averager[i] = platform_state.time_averager[i + 1];
    }
    platform_state.time_averager[TIME_HISTORY_COUNT - 1] = delta_time;
    averager_sum : u64 = 0;
    for i := 0; i < TIME_HISTORY_COUNT; i += 1 {
        averager_sum += platform_state.time_averager[i];
    }
    delta_time = averager_sum / TIME_HISTORY_COUNT;

    platform_state.averager_residual += averager_sum % TIME_HISTORY_COUNT;
    delta_time += platform_state.averager_residual / TIME_HISTORY_COUNT;
    platform_state.averager_residual %= TIME_HISTORY_COUNT;

    // add to the accumulator
    platform_state.frame_accumulator += delta_time;

    // spiral of death protection
    if platform_state.frame_accumulator > platform_state.desired_frametime * 8 {
        platform_state.resync = true;
    }

    // timer platform_state.resync if requested
    if platform_state.resync {
        platform_state.frame_accumulator = 0;
        delta_time = platform_state.desired_frametime;
        platform_state.resync = false;
    }

    return delta_time;
}

update_and_render :: proc(
    platform_state: ^Platform_State,
    app: ^App,
) {
    profiler_zone("update_and_render", 0x005500);

    game_update := cast(Update_Proc) _game_update_proc;
    game_fixed_update := cast(Update_Proc) _game_fixed_update_proc;
    game_render := cast(Update_Proc) _game_render_proc;

    delta_time := calculate_delta_time(platform_state);
    process_events(platform_state);

    if platform_state.unlock_framerate {
        consumed_delta_time : u64 = delta_time;

        for platform_state.frame_accumulator >= platform_state.desired_frametime {
            game_fixed_update(platform_state.fixed_deltatime, app);
            _frame_fixed_update_count += 1;
            // cap variable update's dt to not be larger than fixed update, and interleave it (so game state can always get animation frames it needs)
            if consumed_delta_time > platform_state.desired_frametime {
                game_update(platform_state.fixed_deltatime, app);
                _frame_update_count += 1;
                consumed_delta_time -= platform_state.desired_frametime;
            }
            platform_state.frame_accumulator -= platform_state.desired_frametime;
            reset_inputs(platform_state);
        }

        game_update(f64(consumed_delta_time / sdl2.GetPerformanceFrequency()), app);
        _frame_update_count += 1;
        game_render(f64(platform_state.frame_accumulator / platform_state.desired_frametime), app);
        _frame_render_count += 1;
    } else {
        for platform_state.frame_accumulator >= platform_state.desired_frametime * u64(platform_state.update_multiplicity) {
            for i := 0; i < platform_state.update_multiplicity; i += 1 {
                game_fixed_update(platform_state.fixed_deltatime, app);
                _frame_fixed_update_count += 1;
                game_update(platform_state.fixed_deltatime, app);
                _frame_update_count += 1;
                platform_state.frame_accumulator -= platform_state.desired_frametime;
                reset_inputs(platform_state);
            }
        }

        game_render(1.0, app);
        _frame_render_count += 1;
    }

    _frame_count += 1;
    _frame_update_count = 0;
    _frame_fixed_update_count = 0;
    _frame_render_count = 0;

    reset_events(platform_state);
    profiler_frame_mark();
    // fmt.printf("frame -> i: %v | unlock: %v | update: %v | fixed: %v | render: %v\n", _frame_count, platform_state.unlock_framerate, _frame_update_count, _frame_fixed_update_count, _frame_render_count);
}

_frame_count := 0;
_frame_update_count := 0;
_frame_fixed_update_count := 0;
_frame_render_count := 0;

@(private="file")
reset_inputs :: proc(platform_state: ^Platform_State) {
    profiler_zone("reset_inputs");

    for key in Scancode {
        (&platform_state.keys[key]).released = false;
        (&platform_state.keys[key]).pressed = false;
    }
    for key in platform_state.mouse_keys {
        (&platform_state.mouse_keys[key]).released = false;
        (&platform_state.mouse_keys[key]).pressed = false;
    }
    for joystick_id, controller_state in platform_state.controllers {
        for key in controller_state.buttons {
            (&controller_state.buttons[key]).released = false;
            (&controller_state.buttons[key]).pressed = false;
        }
    }
    platform_state.input_text = "";
    platform_state.input_scroll.x = 0;
    platform_state.input_scroll.y = 0;
}

@(private="file")
reset_events :: proc(platform_state: ^Platform_State) {
    platform_state.window_resized = false;
}
