package platform

import "core:c"
import "core:fmt"
import "core:image/png"
import "core:log"
import "core:mem"
import "core:os"
import "core:runtime"
import "core:slice"
import "core:strings"
import sdl "vendor:sdl2"

import memory "../../memory"

Surface :: sdl.Surface;
Keycode :: sdl.Keycode;

BUTTON_LEFT     :: sdl.BUTTON_LEFT;
BUTTON_MIDDLE   :: sdl.BUTTON_MIDDLE;
BUTTON_RIGHT    :: sdl.BUTTON_RIGHT;

State :: struct {
    window:             ^sdl.Window,
    quit:               bool,
    inputs:             map[Keycode]Input_State,
    input_mouse_move:   proc(x: i32, y: i32),
    input_mouse_down:   proc(x: i32, y: i32, button: u8),
    input_mouse_up:     proc(x: i32, y: i32, button: u8),
    input_text:         proc(text: string),
    input_scroll:       proc(x: i32, y: i32),
    input_key_down:     proc(keycode: Keycode),
    input_key_up:       proc(keycode: Keycode),
}

Input_State :: struct {
    pressed:    bool,
    released:   bool,
}

@private _state: ^State;
@private _allocator: mem.Allocator;
@private _temp_allocator: mem.Allocator;

init :: proc(allocator: mem.Allocator, temp_allocator: mem.Allocator) -> (state: ^State, ok: bool) {
    context.allocator = allocator;
    _allocator = allocator;
    _temp_allocator = temp_allocator;
    _state = new(State);
    state = _state;

    set_memory_functions_default();

    if error := sdl.Init({ .VIDEO }); error != 0 {
        log.errorf("sdl.init error: %v.", error);
        return;
    }

    for keycode in Keycode {
        _state.inputs[keycode] = Input_State { };
    }

    ok = true;
    log.info("platform.init: OK");
    return;
}

quit :: proc() {
    sdl.Quit();
}

open_window :: proc(title: string, width: i32, height: i32) -> (ok: bool) {
    context.allocator = _allocator;

    _state.window = sdl.CreateWindow(
        strings.clone_to_cstring(title),
        sdl.WINDOWPOS_UNDEFINED, sdl.WINDOWPOS_UNDEFINED,
        width, height, { .SHOWN, .RESIZABLE/* , .ALLOW_HIGHDPI */ });

    if _state.window == nil {
        log.errorf("sdl.CreateWindow error: %v.", sdl.GetError());
        return;
    }

    ok = true;
    return;
}
close_window :: proc() {
    sdl.DestroyWindow(_state.window);
}

process_events :: proc() {
    e: sdl.Event;

    for keycode in Keycode {
        mem.zero(rawptr(&_state.inputs[keycode]), size_of(Input_State));
    }

    for sdl.PollEvent(&e) {
        #partial switch e.type {
            case .QUIT:
                _state.quit = true;

            case .TEXTINPUT: {
                if _state.input_text != nil {
                    _state.input_text(string(cstring(&e.text.text[0])));
                }
            }

            case .MOUSEMOTION: {
                if _state.input_mouse_move != nil {
                    _state.input_mouse_move(e.motion.x, e.motion.y);
                }
            }
            case .MOUSEBUTTONUP: {
                if _state.input_mouse_up != nil {
                    _state.input_mouse_up(e.button.x, e.button.y, e.button.button);
                }
            }
            case .MOUSEBUTTONDOWN: {
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
                if e.type == .KEYUP && e.key.keysym.sym == .ESCAPE {
                    sdl.PushEvent(&sdl.Event{ type = .QUIT });
                }

                input_state := _state.inputs[e.key.keysym.sym];

                if e.type == .KEYUP {
                    input_state.released = true;
                    if _state.input_key_up != nil {
                        _state.input_key_up(e.key.keysym.sym);
                    }
                } else {
                    input_state.pressed = true;
                    if _state.input_key_down != nil {
                        _state.input_key_down(e.key.keysym.sym);
                    }
                }
                _state.inputs[e.key.keysym.sym] = input_state;
            }
        }
    }
}

load_surface_from_image_file :: proc(image_path: string) -> (surface: ^Surface, ok: bool) {
    context.allocator = _allocator;

    path := strings.clone_to_cstring(image_path);
    defer delete(path);

    if strings.has_suffix(image_path, ".bmp") {
        surface = sdl.LoadBMP(path);
    } else {
        res_img, res_error := png.load(image_path);
        if res_error != nil {
            log.errorf("Couldn't load %v.", image_path)
            return;
        }

        // Convert into an SDL2 Surface.
        rmask := u32(0x000000ff);
        gmask := u32(0x0000ff00);
        bmask := u32(0x00ff0000);
        amask := u32(0xff000000) if res_img.channels == 4 else u32(0x0);
        depth := i32(res_img.depth) * i32(res_img.channels);
        pitch := i32(res_img.width) * i32(res_img.channels);

        surface = sdl.CreateRGBSurfaceFrom(
            raw_data(res_img.pixels.buf),
            i32(res_img.width), i32(res_img.height), depth, pitch,
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
    sdl.FreeSurface(surface);
}

set_memory_functions_default :: proc() {
    memory_error := sdl.SetMemoryFunctions(
        sdl.malloc_func(sdl_malloc),   sdl.calloc_func(sdl_calloc),
        sdl.realloc_func(sdl_realloc), sdl.free_func(sdl_free),
    );
    if memory_error > 0 {
        log.errorf("SetMemoryFunctions error: %v", memory_error);
    }
}

sdl_malloc   :: proc(size: c.size_t)              -> rawptr {
    if slice.contains(os.args, "show-alloc") {
        fmt.printf("sdl_malloc:  %v\n", size);
    }
    return mem.alloc(int(size), mem.DEFAULT_ALIGNMENT, _allocator);
}
sdl_calloc   :: proc(nmemb, size: c.size_t)       -> rawptr {
    if slice.contains(os.args, "show-alloc") {
        fmt.printf("sdl_calloc:  %v * %v\n", nmemb, size);
    }
    len := int(nmemb * size);
    ptr := mem.alloc(len, mem.DEFAULT_ALIGNMENT, _allocator);
    return mem.zero(ptr, len);
}
sdl_realloc  :: proc(_mem: rawptr, size: c.size_t) -> rawptr {
    if slice.contains(os.args, "show-alloc") {
        fmt.printf("sdl_realloc: %v | %v\n", _mem, size);
    }
    return mem.resize(_mem, int(size), int(size), mem.DEFAULT_ALIGNMENT, _allocator);
}
sdl_free     :: proc(_mem: rawptr) {
    if slice.contains(os.args, "show-alloc") {
        fmt.printf("sdl_free:    %v\n", _mem);
    }
    mem.free(_mem, _allocator);
}

set_memory_functions_temp :: proc() {
    memory_error := sdl.SetMemoryFunctions(
        sdl.malloc_func(sdl_malloc_temp),   sdl.calloc_func(sdl_calloc_temp),
        sdl.realloc_func(sdl_realloc_temp), sdl.free_func(sdl_free_temp),
    );
    if memory_error > 0 {
        log.errorf("SetMemoryFunctions error: %v", memory_error);
    }
}

sdl_malloc_temp   :: proc(size: c.size_t)              -> rawptr {
    // if slice.contains(os.args, "show-alloc") {
    //     fmt.printf("sdl_malloc_temp:  %v\n", size);
    // }
    return mem.alloc(int(size), mem.DEFAULT_ALIGNMENT, _temp_allocator);
}
sdl_calloc_temp   :: proc(nmemb, size: c.size_t)       -> rawptr {
    // if slice.contains(os.args, "show-alloc") {
    //     fmt.printf("sdl_calloc_temp:  %v * %v\n", nmemb, size);
    // }
    len := int(nmemb * size);
    ptr := mem.alloc(len, mem.DEFAULT_ALIGNMENT, _temp_allocator);
    return mem.zero(ptr, len);
}
sdl_realloc_temp  :: proc(_mem: rawptr, size: c.size_t) -> rawptr {
    // if slice.contains(os.args, "show-alloc") {
    //     fmt.printf("sdl_realloc_temp: %v | %v\n", _mem, size);
    // }
    return mem.resize(_mem, int(size), int(size), mem.DEFAULT_ALIGNMENT, _temp_allocator);
}
sdl_free_temp     :: proc(_mem: rawptr) {
    // if slice.contains(os.args, "show-alloc") {
    //     fmt.printf("sdl_free_temp:    %v\n", _mem);
    // }
    mem.free(_mem, _temp_allocator);
}

allocator_proc :: proc(
    allocator_data: rawptr, mode: mem.Allocator_Mode,
    size, alignment: int,
    old_memory: rawptr, old_size: int, location := #caller_location,
) -> (result: []byte, error: mem.Allocator_Error) {
    if slice.contains(os.args, "show-alloc") {
        fmt.printf("[PLATFORM] %v %v byte at %v\n", mode, size, location);
    }
    result, error = runtime.default_allocator_proc(allocator_data, mode, size, alignment, old_memory, old_size, location);
    if error > .None {
        fmt.eprintf("[PLATFORM] alloc error %v\n", error);
        os.exit(0);
    }
    return;
}
