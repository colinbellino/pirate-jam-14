package engine_platform

import "core:log"
import "core:math"
import "core:mem"
import "core:os"
import "core:slice"
import "core:strings"
import "vendor:sdl2"
import "vendor:stb/image"

import engine_math "../math"
import "../../bla"

Surface :: sdl2.Surface;
Keycode :: sdl2.Keycode;
Window :: sdl2.Window;
Vector2i :: engine_math.Vector2i;

BUTTON          :: sdl2.BUTTON;
BUTTON_LEFT     :: sdl2.BUTTON_LEFT;
BUTTON_MIDDLE   :: sdl2.BUTTON_MIDDLE;
BUTTON_RIGHT    :: sdl2.BUTTON_RIGHT;

APP_BASE_ADDRESS        :: 2 * mem.Terabyte;
APP_ARENA_SIZE          :: 8 * mem.Megabyte;
TIME_HISTORY_COUNT      :: 4;
SNAP_FREQUENCY_COUNT    :: 5;

Platform_State :: struct {
    marker_0:               bla.Memory_Marker,

    arena:                  ^mem.Arena,
    allocator:              mem.Allocator,
    temp_allocator:         mem.Allocator,
    code_reload_requested:  bool,
    window:                 ^Window,
    quit:                   bool,
    window_resized:         bool,
    keys:                   map[Keycode]Key_State,
    mouse_keys:             map[i32]Key_State,
    mouse_position:         Vector2i,
    input_text:             string,
    input_scroll:           Vector2i,

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

    marker_1:               bla.Memory_Marker,
}

Key_State :: struct {
    pressed:    bool,
    released:   bool,
}

Update_Proc :: #type proc(delta_time: f64, game_memory: rawptr)

init :: proc(allocator: mem.Allocator, temp_allocator: mem.Allocator) -> (state: ^Platform_State, ok: bool) {
    context.allocator = allocator;

    state = new(Platform_State);
    state.allocator = allocator;
    state.temp_allocator = temp_allocator;
    state.arena = cast(^mem.Arena)allocator.data;
    state.marker_0 = bla.Memory_Marker { '#', '#', '#', 'P', 'L', 'A', 'T', '_', 'S', 'T', 'A', 'T', 'E', '0', '#', '#' };
    state.marker_1 = bla.Memory_Marker { '#', '#', '#', 'P', 'L', 'A', 'T', '_', 'S', 'T', 'A', 'T', 'E', '1', '#', '#' };

    _allocator = allocator;
    _temp_allocator = temp_allocator;
    set_memory_functions_default();

    if error := sdl2.Init({ .VIDEO }); error != 0 {
        log.errorf("sdl2.Init error: %v.", error);
        return;
    }

    for key in Keycode {
        state.keys[key] = Key_State { };
    }
    state.mouse_keys[BUTTON_LEFT] = Key_State { };
    state.mouse_keys[BUTTON_MIDDLE] = Key_State { };
    state.mouse_keys[BUTTON_RIGHT] = Key_State { };

    // // Framerate preparations (source: http://web.archive.org/web/20221205112541/https://github.com/TylerGlaiel/FrameTimingControl)
    // {
    //     state.update_rate = 60;
    //     state.update_multiplicity = 1;

    //     // compute how many ticks one update should be
    //     state.fixed_deltatime = f64(1.0) / f64(state.update_rate);
    //     state.desired_frametime = sdl2.GetPerformanceFrequency() / u64(state.update_rate);

    //     // these are to snap deltaTime to vsync values if it's close enough
    //     state.vsync_maxerror = sdl2.GetPerformanceFrequency() / 5000;
    //     time_60hz : u64 = sdl2.GetPerformanceFrequency() / 60; // since this is about snapping to common vsync values
    //     state.snap_frequencies = {
    //         time_60hz,           // 60fps
    //         time_60hz * 2,       // 30fps
    //         time_60hz * 3,       // 20fps
    //         time_60hz * 4,       // 15fps
    //         (time_60hz + 1) / 2, // 120fps //120hz, 240hz, or higher need to round up, so that adding 120hz twice guaranteed is at least the same as adding time_60hz once
    //     };

    //     state.time_averager = { state.desired_frametime, state.desired_frametime, state.desired_frametime, state.desired_frametime };
    //     state.averager_residual = 0;

    //     state.resync = true;
    //     state.prev_frame_time = sdl2.GetPerformanceCounter();
    //     state.frame_accumulator = 0;
    // }

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
                key.released = true;
                key.pressed = false;
            }
            case .MOUSEBUTTONDOWN: {
                key := &platform_state.mouse_keys[i32(e.button.button)];
                key.released = false;
                key.pressed = true;
            }
            case .MOUSEWHEEL: {
                platform_state.input_scroll.x = e.wheel.x;
                platform_state.input_scroll.y = e.wheel.y;
            }

            case .KEYDOWN, .KEYUP: {
                key := &platform_state.keys[e.key.keysym.sym];
                key.released = e.type == .KEYUP;
                key.pressed = e.type == .KEYDOWN;
            }
        }
    }
}

reset_inputs :: proc(platform_state: ^Platform_State) {
    for key in Keycode {
        (&platform_state.keys[key]).released = false;
        (&platform_state.keys[key]).pressed = false;
    }
    for key in platform_state.mouse_keys {
        (&platform_state.mouse_keys[key]).released = false;
        (&platform_state.mouse_keys[key]).pressed = false;
    }
    platform_state.input_text = "";
    platform_state.input_scroll.x = 0;
    platform_state.input_scroll.y = 0;
}

reset_events :: proc(platform_state: ^Platform_State) {
    platform_state.window_resized = false;
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

get_ticks :: proc() -> u32 {
    return sdl2.GetTicks();
}

update_and_render :: proc(
    platform_state: ^Platform_State,
    game_update_proc, game_fixed_update_proc, game_render_proc: rawptr,
    game_memory: rawptr,
) {
    game_update := cast(Update_Proc) game_update_proc;
    game_fixed_update := cast(Update_Proc) game_fixed_update_proc;
    game_render := cast(Update_Proc) game_render_proc;

    // // frame timer
    // current_frame_time : u64 = sdl2.GetPerformanceCounter();
    // delta_time : u64 = current_frame_time - platform_state.prev_frame_time;
    // platform_state.prev_frame_time = current_frame_time;

    // // handle unexpected timer anomalies (overflow, extra slow frames, etc)
    // if delta_time > platform_state.desired_frametime * 8 { // ignore extra-slow frames
    //     delta_time = platform_state.desired_frametime;
    // }
    // if delta_time < 0 {
    //     delta_time = 0;
    // }

    // // vsync time snapping
    // for snap in platform_state.snap_frequencies {
    //     if math.abs(delta_time - snap) < platform_state.vsync_maxerror {
    //         delta_time = snap;
    //         break;
    //     }
    // }

    // // delta time averaging
    // for i := 0; i < TIME_HISTORY_COUNT - 1; i += 1 {
    //     platform_state.time_averager[i] = platform_state.time_averager[i + 1];
    // }
    // platform_state.time_averager[TIME_HISTORY_COUNT - 1] = delta_time;
    // averager_sum : u64 = 0;
    // for i := 0; i < TIME_HISTORY_COUNT; i += 1 {
    //     averager_sum += platform_state.time_averager[i];
    // }
    // delta_time = averager_sum / TIME_HISTORY_COUNT;

    // platform_state.averager_residual += averager_sum % TIME_HISTORY_COUNT;
    // delta_time += platform_state.averager_residual / TIME_HISTORY_COUNT;
    // platform_state.averager_residual %= TIME_HISTORY_COUNT;

    // // add to the accumulator
    // platform_state.frame_accumulator += delta_time;

    // // spiral of death protection
    // if platform_state.frame_accumulator > platform_state.desired_frametime * 8 {
    //     platform_state.resync = true;
    // }

    // // timer platform_state.resync if requested
    // if platform_state.resync {
    //     platform_state.frame_accumulator = 0;
    //     delta_time = platform_state.desired_frametime;
    //     platform_state.resync = false;
    // }

    process_events(platform_state);
    // _frame_update := 0;

    // if platform_state.unlock_framerate {
    //     consumed_delta_time : u64 = delta_time;

    //     for platform_state.frame_accumulator >= platform_state.desired_frametime {
    //         game_fixed_update(platform_state.fixed_deltatime, game_memory);
    //         // cap variable update's dt to not be larger than fixed update, and interleave it (so game state can always get animation frames it needs)
    //         if consumed_delta_time > platform_state.desired_frametime {
    //             game_update(platform_state.fixed_deltatime, game_memory);
    //             consumed_delta_time -= platform_state.desired_frametime;
    //         }
    //         platform_state.frame_accumulator -= platform_state.desired_frametime;
    //         reset_inputs(platform_state);
    //     }

    //     game_update(f64(consumed_delta_time / sdl2.GetPerformanceFrequency()), game_memory);
    //     game_render(f64(platform_state.frame_accumulator / platform_state.desired_frametime), game_memory);
    // } else {
    //     for platform_state.frame_accumulator >= platform_state.desired_frametime * u64(platform_state.update_multiplicity) {
    //         for i := 0; i < platform_state.update_multiplicity; i += 1 {
    //             game_fixed_update(platform_state.fixed_deltatime, game_memory);
    //             game_update(platform_state.fixed_deltatime, game_memory);
    //             platform_state.frame_accumulator -= platform_state.desired_frametime;
    //             reset_inputs(platform_state);
    //             _frame_update += 1;
    //         }
    //     }

    //     game_render(1.0, game_memory);
    // }

    // FIXME: Enable the unlock_framerate branch above
    game_fixed_update(1.0, game_memory);
    game_update(1.0, game_memory);
    game_render(1.0, game_memory);
    reset_inputs(platform_state);
    reset_events(platform_state);

    // log.debugf("frame_info | game_update: %v | i: %v | acc: %v | ft: %v",
    //     _frame, _frame_update, platform_state.frame_accumulator,
    //     platform_state.desired_frametime * u64(platform_state.update_multiplicity),
    // );

    // if contains_os_args("log-frame") {
    //     log.warnf("End of frame (%v)", _frame);
    // }
    // _frame += 1;
}

// _frame: i32;
