package engine_platform

import "core:log"
import "core:math"
import "core:mem"
import "core:os"
import "core:runtime"
import "core:slice"
import "core:strings"
import "vendor:sdl2"
import "vendor:stb/image"

import engine_math "../math"
// import profiler "../profiler"

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
    arena:                  ^mem.Arena,
    window:                 ^Window,
    quit:                   bool,
    window_resized:         bool,
    keys:                   map[Keycode]Key_State,
    mouse_keys:             map[i32]Key_State,
    mouse_position:         Vector2i,

    input_mouse_move:       proc(x: i32, y: i32),
    input_mouse_down:       proc(x: i32, y: i32, button: u8),
    input_mouse_up:         proc(x: i32, y: i32, button: u8),
    input_text:             proc(text: string),
    input_scroll:           proc(x: i32, y: i32),
    input_key_down:         proc(keycode: Keycode),
    input_key_up:           proc(keycode: Keycode),

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

Key_State :: struct {
    pressed:    bool,
    released:   bool,
}

Update_Proc :: #type proc(
    arena_allocator: runtime.Allocator,
    delta_time: f64,
    game_state, platform_state, renderer_state, logger_state, ui_state: rawptr,
)

@private _state: ^Platform_State;
@private _allocator: mem.Allocator;
@private _temp_allocator: mem.Allocator;

init :: proc(allocator: mem.Allocator, temp_allocator: mem.Allocator) -> (state: ^Platform_State, ok: bool) {
    context.allocator = allocator;

    _allocator = allocator;
    _temp_allocator = temp_allocator;
    _state = new(Platform_State);
    _state.arena = cast(^mem.Arena)allocator.data;
    state = _state;

    set_memory_functions_default();

    if error := sdl2.Init({ .VIDEO }); error != 0 {
        log.errorf("sdl2.Init error: %v.", error);
        return;
    }

    for key in Keycode {
        _state.keys[key] = Key_State { };
    }
    _state.mouse_keys[BUTTON_LEFT] = Key_State { };
    _state.mouse_keys[BUTTON_MIDDLE] = Key_State { };
    _state.mouse_keys[BUTTON_RIGHT] = Key_State { };

    // Framerate preparations (source: http://web.archive.org/web/20221205112541/https://github.com/TylerGlaiel/FrameTimingControl)
    {
        _state.update_rate = 60;
        _state.update_multiplicity = 1;

        // compute how many ticks one update should be
        _state.fixed_deltatime = f64(1.0) / f64(_state.update_rate);
        _state.desired_frametime = sdl2.GetPerformanceFrequency() / u64(_state.update_rate);

        // these are to snap deltaTime to vsync values if it's close enough
        _state.vsync_maxerror = sdl2.GetPerformanceFrequency() / 5000;
        time_60hz : u64 = sdl2.GetPerformanceFrequency() / 60; // since this is about snapping to common vsync values
        _state.snap_frequencies = {
            time_60hz,           // 60fps
            time_60hz * 2,       // 30fps
            time_60hz * 3,       // 20fps
            time_60hz * 4,       // 15fps
            (time_60hz + 1) / 2, // 120fps //120hz, 240hz, or higher need to round up, so that adding 120hz twice guaranteed is at least the same as adding time_60hz once
        };

        _state.time_averager = { _state.desired_frametime, _state.desired_frametime, _state.desired_frametime, _state.desired_frametime };
        _state.averager_residual = 0;

        _state.resync = true;
        _state.prev_frame_time = sdl2.GetPerformanceCounter();
        _state.frame_accumulator = 0;
    }

    ok = true;
    // log.info("init: OK");
    return;
}

quit :: proc() {
    sdl2.Quit();
}

open_window :: proc(title: string, size: Vector2i) -> (ok: bool) {
    context.allocator = _allocator;

    _state.window = sdl2.CreateWindow(
        strings.clone_to_cstring(title),
        sdl2.WINDOWPOS_UNDEFINED, sdl2.WINDOWPOS_UNDEFINED,
        size.x, size.y, { .SHOWN, .RESIZABLE, .ALLOW_HIGHDPI },
    );
    _state.window_resized = true;

    if _state.window == nil {
        log.errorf("sdl2.CreateWindow error: %v.", sdl2.GetError());
        return;
    }

    ok = true;
    return;
}
close_window :: proc() {
    sdl2.DestroyWindow(_state.window);
}

process_events :: proc() {
    e: sdl2.Event;

    for sdl2.PollEvent(&e) {
        #partial switch e.type {
            case .QUIT:
                _state.quit = true;

            case .WINDOWEVENT: {
                window_event := (^sdl2.WindowEvent)(&e)^;
                #partial switch window_event.event {
                    case .RESIZED: {
                        _state.window_resized = true;
                    }
                    case .SHOWN: {
                        _state.window_resized = true;
                    }
                    // case: {
                    //     log.debugf("window_event: %v", window_event);
                    // }
                }
            }

            case .TEXTINPUT: {
                if _state.input_text != nil {
                    _state.input_text(string(cstring(&e.text.text[0])));
                }
            }

            case .MOUSEMOTION: {
                _state.mouse_position.x = e.motion.x;
                _state.mouse_position.y = e.motion.y;
                if _state.input_mouse_move != nil {
                    _state.input_mouse_move(e.motion.x, e.motion.y);
                }
            }
            case .MOUSEBUTTONUP: {
                key := &_state.mouse_keys[i32(e.button.button)];
                key.released = true;
                if _state.input_mouse_up != nil {
                    _state.input_mouse_up(e.button.x, e.button.y, e.button.button);
                }
            }
            case .MOUSEBUTTONDOWN: {
                key := &_state.mouse_keys[i32(e.button.button)];
                key.pressed = true;
                if _state.input_mouse_down != nil {
                    _state.input_mouse_down(e.button.x, e.button.y, e.button.button);
                }
            }
            case .MOUSEWHEEL: {
                if _state.input_scroll != nil {
                    _state.input_scroll(e.wheel.x * 30, e.wheel.y * -30);
                }
            }

            case .KEYDOWN, .KEYUP: {
                key := _state.keys[e.key.keysym.sym];
                key.released = e.type == .KEYUP;
                key.pressed = e.type == .KEYDOWN;
                _state.keys[e.key.keysym.sym] = key;

                if e.type == .KEYUP {
                    key.pressed = false;
                    if _state.input_key_up != nil {
                        _state.input_key_up(e.key.keysym.sym);
                    }
                } else {
                    if _state.input_key_down != nil {
                        _state.input_key_down(e.key.keysym.sym);
                    }
                }
            }
        }
    }
}

reset_inputs :: proc() {
    for key in Keycode {
        (&_state.keys[key]).released = false;
    }
    for key in _state.mouse_keys {
        (&_state.mouse_keys[key]).released = false;
    }
}

reset_events :: proc() {
    _state.window_resized = false;
}

contains_os_args :: proc(value: string) -> bool {
    return slice.contains(os.args, value);
}

load_surface_from_image_file :: proc(image_path: string) -> (surface: ^Surface, ok: bool) {
    context.allocator = _allocator;

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
    unlock_framerate: bool,
    fixed_update_proc, variable_update_proc, render_proc: Update_Proc,
    arena_allocator: runtime.Allocator,
    game_state, platform_state, renderer_state, logger_state, ui_state: rawptr,
) {
    // frame timer
    current_frame_time : u64 = sdl2.GetPerformanceCounter();
    delta_time : u64 = current_frame_time - _state.prev_frame_time;
    _state.prev_frame_time = current_frame_time;

    // handle unexpected timer anomalies (overflow, extra slow frames, etc)
    if delta_time > _state.desired_frametime * 8 { // ignore extra-slow frames
        delta_time = _state.desired_frametime;
    }
    if delta_time < 0 {
        delta_time = 0;
    }

    // vsync time snapping
    for snap in _state.snap_frequencies {
        if math.abs(delta_time - snap) < _state.vsync_maxerror {
            delta_time = snap;
            break;
        }
    }

    // delta time averaging
    for i := 0; i < TIME_HISTORY_COUNT - 1; i += 1 {
        _state.time_averager[i] = _state.time_averager[i + 1];
    }
    _state.time_averager[TIME_HISTORY_COUNT - 1] = delta_time;
    averager_sum : u64 = 0;
    for i := 0; i < TIME_HISTORY_COUNT; i += 1 {
        averager_sum += _state.time_averager[i];
    }
    delta_time = averager_sum / TIME_HISTORY_COUNT;

    _state.averager_residual += averager_sum % TIME_HISTORY_COUNT;
    delta_time += _state.averager_residual / TIME_HISTORY_COUNT;
    _state.averager_residual %= TIME_HISTORY_COUNT;

    // add to the accumulator
    _state.frame_accumulator += delta_time;

    // spiral of death protection
    if _state.frame_accumulator > _state.desired_frametime * 8 {
        _state.resync = true;
    }

    // timer _state.resync if requested
    if _state.resync {
        _state.frame_accumulator = 0;
        delta_time = _state.desired_frametime;
        _state.resync = false;
    }

    process_events();

    if unlock_framerate {
        consumed_delta_time : u64 = delta_time;

        for _state.frame_accumulator >= _state.desired_frametime {
            fixed_update_proc(arena_allocator, _state.fixed_deltatime, game_state, platform_state, renderer_state, logger_state, ui_state);
            // cap variable update's dt to not be larger than fixed update, and interleave it (so game state can always get animation frames it needs)
            if consumed_delta_time > _state.desired_frametime {
                variable_update_proc(arena_allocator, _state.fixed_deltatime, game_state, platform_state, renderer_state, logger_state, ui_state);
                consumed_delta_time -= _state.desired_frametime;
            }
            _state.frame_accumulator -= _state.desired_frametime;
            reset_inputs();
        }

        variable_update_proc(arena_allocator, f64(consumed_delta_time / sdl2.GetPerformanceFrequency()), game_state, platform_state, renderer_state, logger_state, ui_state);
        render_proc(arena_allocator, f64(_state.frame_accumulator / _state.desired_frametime), game_state, platform_state, renderer_state, logger_state, ui_state);
    } else {
        for _state.frame_accumulator >= _state.desired_frametime * u64(_state.update_multiplicity) {
            for i := 0; i < _state.update_multiplicity; i += 1 {
                fixed_update_proc(arena_allocator, _state.fixed_deltatime, game_state, platform_state, renderer_state, logger_state, ui_state);
                variable_update_proc(arena_allocator, _state.fixed_deltatime, game_state, platform_state, renderer_state, logger_state, ui_state);
                _state.frame_accumulator -= _state.desired_frametime;
                reset_inputs();
            }
        }

        render_proc(arena_allocator, 1.0, game_state, platform_state, renderer_state, logger_state, ui_state);
    }

    reset_events();

    if contains_os_args("log-frame") {
        log.warnf("End of frame (%v)", _frame);
    }
    _frame += 1;
}

_frame: i32;
