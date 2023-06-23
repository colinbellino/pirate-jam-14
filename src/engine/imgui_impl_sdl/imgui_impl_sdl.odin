package imgui_impl_sdl;

import "core:runtime";
import "vendor:sdl2"

import imgui "../../odin-imgui";

SDL_State :: struct {
    time: u64,
    mouse_down: [3]bool,
    cursor_handles: [imgui.Mouse_Cursor.Count]^sdl2.Cursor,
}

setup_state :: proc(using state: ^SDL_State) {
    io := imgui.get_io();
    io.backend_platform_name = "SDL";
    io.backend_flags |= .HasMouseCursors;

    io.key_map[imgui.Key.Tab]         = i32(sdl2.Scancode.TAB);
    io.key_map[imgui.Key.LeftArrow]   = i32(sdl2.Scancode.LEFT);
    io.key_map[imgui.Key.RightArrow]  = i32(sdl2.Scancode.RIGHT);
    io.key_map[imgui.Key.UpArrow]     = i32(sdl2.Scancode.UP);
    io.key_map[imgui.Key.DownArrow]   = i32(sdl2.Scancode.DOWN);
    io.key_map[imgui.Key.PageUp]      = i32(sdl2.Scancode.PAGEUP);
    io.key_map[imgui.Key.PageDown]    = i32(sdl2.Scancode.PAGEDOWN);
    io.key_map[imgui.Key.Home]        = i32(sdl2.Scancode.HOME);
    io.key_map[imgui.Key.End]         = i32(sdl2.Scancode.END);
    io.key_map[imgui.Key.Insert]      = i32(sdl2.Scancode.INSERT);
    io.key_map[imgui.Key.Delete]      = i32(sdl2.Scancode.DELETE);
    io.key_map[imgui.Key.Backspace]   = i32(sdl2.Scancode.BACKSPACE);
    io.key_map[imgui.Key.Space]       = i32(sdl2.Scancode.SPACE);
    io.key_map[imgui.Key.Enter]       = i32(sdl2.Scancode.RETURN);
    io.key_map[imgui.Key.Escape]      = i32(sdl2.Scancode.ESCAPE);
    io.key_map[imgui.Key.KeyPadEnter] = i32(sdl2.Scancode.KP_ENTER);
    io.key_map[imgui.Key.A]           = i32(sdl2.Scancode.A);
    io.key_map[imgui.Key.C]           = i32(sdl2.Scancode.C);
    io.key_map[imgui.Key.V]           = i32(sdl2.Scancode.V);
    io.key_map[imgui.Key.X]           = i32(sdl2.Scancode.X);
    io.key_map[imgui.Key.Y]           = i32(sdl2.Scancode.Y);
    io.key_map[imgui.Key.Z]           = i32(sdl2.Scancode.Z);

    io.get_clipboard_text_fn = get_clipboard_text;
    io.set_clipboard_text_fn = set_clipboard_text;

    cursor_handles[imgui.Mouse_Cursor.Arrow]      = sdl2.CreateSystemCursor(sdl2.SystemCursor.ARROW);
    cursor_handles[imgui.Mouse_Cursor.TextInput]  = sdl2.CreateSystemCursor(sdl2.SystemCursor.IBEAM);
    cursor_handles[imgui.Mouse_Cursor.ResizeAll]  = sdl2.CreateSystemCursor(sdl2.SystemCursor.SIZEALL);
    cursor_handles[imgui.Mouse_Cursor.ResizeNs]   = sdl2.CreateSystemCursor(sdl2.SystemCursor.SIZENS);
    cursor_handles[imgui.Mouse_Cursor.ResizeEw]   = sdl2.CreateSystemCursor(sdl2.SystemCursor.SIZEWE);
    cursor_handles[imgui.Mouse_Cursor.ResizeNesw] = sdl2.CreateSystemCursor(sdl2.SystemCursor.SIZENESW);
    cursor_handles[imgui.Mouse_Cursor.ResizeNwse] = sdl2.CreateSystemCursor(sdl2.SystemCursor.SIZENWSE);
    cursor_handles[imgui.Mouse_Cursor.Hand]       = sdl2.CreateSystemCursor(sdl2.SystemCursor.HAND);
    cursor_handles[imgui.Mouse_Cursor.NotAllowed] = sdl2.CreateSystemCursor(sdl2.SystemCursor.NO);
}

process_event :: proc(e: sdl2.Event, state: ^SDL_State) {
    io := imgui.get_io();
    #partial switch e.type {
        case .MOUSEWHEEL: {
            if e.wheel.x > 0 do io.mouse_wheel_h += 1;
            if e.wheel.x < 0 do io.mouse_wheel_h -= 1;
            if e.wheel.y > 0 do io.mouse_wheel   += 1;
            if e.wheel.y < 0 do io.mouse_wheel   -= 1;
        }

        case .TEXTINPUT: {
            text := e.text;
            imgui.ImGuiIO_AddInputCharactersUTF8(io, cstring(&text.text[0]));
        }

        case .MOUSEBUTTONDOWN: {
            if e.button.button == u8(sdl2.BUTTON_LEFT)   { state.mouse_down[0] = true; }
            if e.button.button == u8(sdl2.BUTTON_RIGHT)  { state.mouse_down[1] = true; }
            if e.button.button == u8(sdl2.BUTTON_MIDDLE) { state.mouse_down[2] = true; }
        }

        case .KEYDOWN, .KEYUP: {
            sc := e.key.keysym.scancode;
            io.keys_down[sc] = e.type == .KEYDOWN;
            io.key_shift = sdl2.GetModState() & transmute(sdl2.Keymod) (sdl2.KeymodFlag.LSHIFT|sdl2.KeymodFlag.RSHIFT) != nil;
            io.key_ctrl  = sdl2.GetModState() & transmute(sdl2.Keymod) (sdl2.KeymodFlag.LCTRL|sdl2.KeymodFlag.RCTRL)   != nil;
            io.key_alt   = sdl2.GetModState() & transmute(sdl2.Keymod) (sdl2.KeymodFlag.LALT|sdl2.KeymodFlag.RALT)     != nil;

            when ODIN_OS == .Windows {
                io.key_super = false;
            } else {
                io.key_super = sdl2.GetModState() & transmute(sdl2.Keymod) (sdl2.KeymodFlag.LGUI|sdl2.KeymodFlag.RGUI) != nil;
            }
        }
    }
}

update_dt :: proc(state: ^SDL_State, delta_time: f32) {
    io := imgui.get_io();
    io.delta_time = delta_time;
    state.time = sdl2.GetPerformanceCounter();
}

update_mouse :: proc(state: ^SDL_State, window: ^sdl2.Window) {
    io := imgui.get_io();
    mx, my: i32;
    buttons := sdl2.GetMouseState(&mx, &my);
    io.mouse_down[0] = state.mouse_down[0] || (buttons & u32(sdl2.BUTTON_LEFT))   != 0;
    io.mouse_down[1] = state.mouse_down[1] || (buttons & u32(sdl2.BUTTON_RIGHT))  != 0;
    io.mouse_down[2] = state.mouse_down[2] || (buttons & u32(sdl2.BUTTON_MIDDLE)) != 0;
    state.mouse_down[0] = false;
    state.mouse_down[1] = false;
    state.mouse_down[2] = false;

    // Set mouse pos if window is focused
    io.mouse_pos = imgui.Vec2{min(f32), min(f32)};
    if sdl2.GetKeyboardFocus() == window {
        io.mouse_pos = imgui.Vec2{f32(mx), f32(my)};
    }

    if io.config_flags & .NoMouseCursorChange != .NoMouseCursorChange {
        desired_cursor := imgui.get_mouse_cursor();
        if(io.mouse_draw_cursor || desired_cursor == .None) {
            sdl2.ShowCursor(0);
        } else {
            chosen_cursor := state.cursor_handles[imgui.Mouse_Cursor.Arrow];
            if state.cursor_handles[desired_cursor] != nil {
                chosen_cursor = state.cursor_handles[desired_cursor];
            }
            sdl2.SetCursor(chosen_cursor);
            sdl2.ShowCursor(1);
        }
    }
}

update_display_size :: proc(window: ^sdl2.Window) {
    w, h, display_w, display_h: i32;
    sdl2.GetWindowSize(window, &w, &h);
    if .MINIMIZED in transmute(sdl2.WindowFlags) sdl2.GetWindowFlags(window) {
        w = 0;
        h = 0;
    }
    sdl2.GL_GetDrawableSize(window, &display_w, &display_h);

    io := imgui.get_io();
    io.display_size = imgui.Vec2{f32(w), f32(h)};
    if w > 0 && h > 0 {
        io.display_framebuffer_scale = imgui.Vec2{f32(display_w / w), f32(display_h / h)};
    }
}

set_clipboard_text :: proc "c"(user_data : rawptr, text : cstring) {
    context = runtime.default_context();
    sdl2.SetClipboardText(text);
}

get_clipboard_text :: proc "c"(user_data : rawptr) -> cstring {
    context = runtime.default_context();
    @static text_ptr: cstring;
    if text_ptr != nil {
        sdl2.free(cast(^byte)text_ptr);
    }
    text_ptr = sdl2.GetClipboardText();

    return text_ptr;
}
