package platform

import "core:c"
import "core:fmt"
import "core:image/png"
import "core:log"
import "core:mem"
import "core:mem/virtual"
import "core:os"
import "core:runtime"
import "core:strings"
import sdl "vendor:sdl2"

Surface :: sdl.Surface;
Keycode :: sdl.Keycode;

BUTTON_LEFT :: sdl.BUTTON_LEFT;
BUTTON_MIDDLE :: sdl.BUTTON_MIDDLE;
BUTTON_RIGHT :: sdl.BUTTON_RIGHT;

Inputs :: struct {
    f1:         InputState,
    f2:         InputState,
    f3:         InputState,
    f4:         InputState,
    f12:        InputState,
}

InputState :: struct {
    released:   bool,
}

State :: struct {
    window:             ^sdl.Window,
    quit:               bool,
    inputs:             Inputs,
    input_mouse_move:   proc(x: i32, y: i32),
    input_mouse_down:   proc(x: i32, y: i32, button: u8),
    input_mouse_up:     proc(x: i32, y: i32, button: u8),
    input_text:         proc(text: string),
    input_scroll:       proc(x: i32, y: i32),
    input_key_down:     proc(keycode: Keycode),
    input_key_up:       proc(keycode: Keycode),
    allocator:          ^runtime.Allocator,
}

@private _state: ^State;

init :: proc(state: ^State, allocator: ^runtime.Allocator) -> (ok: bool) {
    _state = state;
    _state.allocator = allocator;

    sdl.SetMemoryFunctions(
        sdl.malloc_func(custom_malloc),
        sdl.calloc_func(custom_calloc),
        sdl.realloc_func(custom_realloc),
        sdl.free_func(custom_free),
    );

    if error := sdl.Init({ .VIDEO }); error != 0 {
        log.error("sdl.init error: %v.", error);
        return;
    }

    ok = true;
    return;
}
quit :: proc() {
    sdl.Quit();
}

custom_malloc   :: proc(size: c.size_t)              -> rawptr {
    // fmt.printf("alloc:   %v\n", size);
    return mem.alloc(int(size), mem.DEFAULT_ALIGNMENT, _state.allocator^);
    // return os.heap_alloc(int(size));
}
custom_calloc   :: proc(nmemb, size: c.size_t)       -> rawptr {
    // fmt.printf("calloc:  %v | %v\n", nmemb, size);
    return mem.alloc(int(nmemb * size), mem.DEFAULT_ALIGNMENT, _state.allocator^);
    // return os.heap_alloc(int(nmemb * size));
}
custom_realloc  :: proc(_mem: rawptr, size: c.size_t) -> rawptr {
    // fmt.printf("realloc: %v | %v\n", _mem, size);
    return mem.resize(_mem, 0, int(size), mem.DEFAULT_ALIGNMENT, _state.allocator^);
    // return os.heap_resize(_mem, int(size));
}
custom_free     :: proc(_mem: rawptr) {
    // fmt.printf("free:    %v\n", _mem);
    mem.free(_mem, _state.allocator^);
    // os.heap_free(_mem);
}

open_window :: proc(title: string, width: i32, height: i32) -> (ok: bool) {
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

    _state.inputs.f1 = {};
    _state.inputs.f2 = {};
    _state.inputs.f3 = {};
    _state.inputs.f4 = {};
    _state.inputs.f12 = {};

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
                    sdl.PushEvent(&sdl.Event{type = .QUIT});
                }

                // TODO: use a map to store the inputs
                if e.key.keysym.sym == .F12 {
                    _state.inputs.f12.released = (e.type == .KEYUP);
                }
                if e.key.keysym.sym == .F1 {
                    _state.inputs.f1.released = (e.type == .KEYUP);
                }
                if e.key.keysym.sym == .F2 {
                    _state.inputs.f2.released = (e.type == .KEYUP);
                }
                if e.key.keysym.sym == .F3 {
                    _state.inputs.f3.released = (e.type == .KEYUP);
                }
                if e.key.keysym.sym == .F4 {
                    _state.inputs.f4.released = (e.type == .KEYUP);
                }

                if e.type == .KEYUP {
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

load_surface_from_image_file :: proc(image_path: string) -> (surface: ^Surface, ok: bool) {
    path := strings.clone_to_cstring(image_path, context.temp_allocator);

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
