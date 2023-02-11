package platform

import "core:fmt"
import sdl "vendor:sdl2"

import ui "../renderer/ui"

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
    window:     ^sdl.Window,
    quit:       bool,
    inputs:     Inputs,
}

state := State {};

init :: proc() {
    if err := sdl.Init({.VIDEO}); err != 0 {
        fmt.eprintln(err);
        return;
    }
}
quit :: proc() {
    sdl.Quit();
}

open_window :: proc(width: i32, height: i32) {
    state.window = sdl.CreateWindow("Tactics", sdl.WINDOWPOS_UNDEFINED, sdl.WINDOWPOS_UNDEFINED, width, height, {.SHOWN, .RESIZABLE});
    if state.window == nil {
        fmt.eprintln(sdl.GetError());
        return;
    }
}
close_window :: proc() {
    sdl.DestroyWindow(state.window);
}

process_inputs :: proc() {
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
            case .MOUSEMOTION:
                ui.input_mouse_move(e.motion.x, e.motion.y);
            case .MOUSEWHEEL:
                ui.input_scroll(e.wheel.x * 30, e.wheel.y * -30);
            case .TEXTINPUT:
                ui.input_text(string(cstring(&e.text.text[0])));

            case .MOUSEBUTTONDOWN, .MOUSEBUTTONUP: {
                fn := ui.input_mouse_down;
                if e.type == .MOUSEBUTTONUP {
                    fn = ui.input_mouse_up;
                }
                switch e.button.button {
                    case sdl.BUTTON_LEFT:   fn(e.button.x, e.button.y, .LEFT);
                    case sdl.BUTTON_MIDDLE: fn(e.button.x, e.button.y, .MIDDLE);
                    case sdl.BUTTON_RIGHT:  fn(e.button.x, e.button.y, .RIGHT);
                }
            }

            case .KEYDOWN, .KEYUP: {
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

                if e.type == .KEYUP && e.key.keysym.sym == .ESCAPE {
                    sdl.PushEvent(&sdl.Event{type = .QUIT});
                }

                fn := ui.input_key_down
                if e.type == .KEYUP {
                    fn = ui.input_key_up;
                }

                #partial switch e.key.keysym.sym {
                    case .LSHIFT:    fn(.SHIFT);
                    case .RSHIFT:    fn(.SHIFT);
                    case .LCTRL:     fn(.CTRL);
                    case .RCTRL:     fn(.CTRL);
                    case .LALT:      fn(.ALT);
                    case .RALT:      fn(.ALT);
                    case .RETURN:    fn(.RETURN);
                    case .KP_ENTER:  fn(.RETURN);
                    case .BACKSPACE: fn(.BACKSPACE);
                }
            }
        }
    }
}
