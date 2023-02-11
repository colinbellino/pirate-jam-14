package platform

import "core:fmt"
import "core:log"
import "core:strings"
import sdl "vendor:sdl2"
import sdl_image "vendor:sdl2/image"

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
    input_key_up:     proc(keycode: Keycode),
}

state := State {};

init :: proc() {
    if err := sdl.Init({ .VIDEO }); err != 0 {
        log.error("sdl.init returned %v.", err);
        return;
    }

    img_init_flags := sdl_image.INIT_PNG;
    img_result := sdl_image.InitFlags(sdl_image.Init(img_init_flags));
    if img_result != img_init_flags {
        log.error("sdl_image.init returned %v.", img_result);
        return;
    }
}
quit :: proc() {
    sdl.Quit();
}

open_window :: proc(width: i32, height: i32) {
    state.window = sdl.CreateWindow("Tactics", sdl.WINDOWPOS_UNDEFINED, sdl.WINDOWPOS_UNDEFINED, width, height, { .SHOWN, .RESIZABLE, .ALLOW_HIGHDPI });
    if state.window == nil {
        log.error(sdl.GetError());
        return;
    }
}
close_window :: proc() {
    sdl.DestroyWindow(state.window);
}

process_events :: proc() {
    e: sdl.Event;

    state.inputs.f1 = {};
    state.inputs.f2 = {};
    state.inputs.f3 = {};
    state.inputs.f4 = {};
    state.inputs.f12 = {};

    for sdl.PollEvent(&e) {
        #partial switch e.type {
            case .QUIT:
                state.quit = true;

            case .TEXTINPUT: {
                if state.input_text != nil {
                    state.input_text(string(cstring(&e.text.text[0])));
                }
            }

            case .MOUSEMOTION: {
                if state.input_mouse_move != nil {
                    state.input_mouse_move(e.motion.x, e.motion.y);
                }
            }
            case .MOUSEBUTTONUP: {
                if state.input_mouse_up != nil {
                    state.input_mouse_up(e.button.x, e.button.y, e.button.button);
                }
            }
            case .MOUSEBUTTONDOWN: {
                if state.input_mouse_down != nil {
                    state.input_mouse_down(e.button.x, e.button.y, e.button.button);
                }
            }
            case .MOUSEWHEEL: {
                if state.input_scroll != nil {
                    state.input_scroll(e.wheel.x * 30, e.wheel.y * -30);
                }
            }

            case .KEYDOWN, .KEYUP: {
                if e.type == .KEYUP && e.key.keysym.sym == .ESCAPE {
                    sdl.PushEvent(&sdl.Event{type = .QUIT});
                }

                // TODO: use a map to store the inputs
                if e.key.keysym.sym == .F12 {
                    state.inputs.f12.released = (e.type == .KEYUP);
                }
                if e.key.keysym.sym == .F1 {
                    state.inputs.f1.released = (e.type == .KEYUP);
                }
                if e.key.keysym.sym == .F2 {
                    state.inputs.f2.released = (e.type == .KEYUP);
                }
                if e.key.keysym.sym == .F3 {
                    state.inputs.f3.released = (e.type == .KEYUP);
                }
                if e.key.keysym.sym == .F4 {
                    state.inputs.f4.released = (e.type == .KEYUP);
                }

                if e.type == .KEYUP {
                    if state.input_key_up != nil {
                        state.input_key_up(e.key.keysym.sym);
                    }
                } else {
                    if state.input_key_down != nil {
                        state.input_key_down(e.key.keysym.sym);
                    }
                }
            }
        }
    }
}

load_surface_from_image_file :: proc(image_path: string) -> (surface: ^Surface, ok: bool) {
    path := strings.clone_to_cstring(image_path, context.temp_allocator);

    surface = sdl_image.Load(path);
    if surface == nil {
        log.errorf("Couldn't load image: %v.", image_path);
    }

    ok = true;
    return;
}

free_surface :: proc(surface: ^Surface) {
    sdl.FreeSurface(surface);
}
