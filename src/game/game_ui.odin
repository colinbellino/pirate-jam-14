package game

import "core:fmt"
import "core:log"

import platform "../engine/platform"
import renderer "../engine/renderer"
import ui "../engine/renderer/ui"
import logger "../engine/logger"
import math "../engine/math"

Game_UI_State :: struct {
    ctx:                ^ui.Context,
    rendering_offset:   ^Vector2i,
    hovered:            bool,
}

@private _state: ^Game_UI_State;

ui_init :: proc(state: ^Game_UI_State, rendering_offset: ^Vector2i, ctx: ^ui.Context) {
    _state = state;
    _state.ctx = ctx;
    _state.rendering_offset = rendering_offset;
}

@(deferred_in_out=ui_scoped_end_window)
ui_window :: proc(title: string, rect: ui.Rect, opt: ui.Options = {}) -> bool {
    final_rect := rect_with_offset(rect, _state.rendering_offset^);
    opened := ui.begin_window(_state.ctx, title, final_rect, opt);
    if ui.mouse_over(_state.ctx, final_rect) {
        _state.hovered = true;
    }
    return opened;
}

@(private="file")
ui_scoped_end_window :: proc(title: string, rect: ui.Rect, opt: ui.Options, opened: bool) {
    ui.scoped_end_window(_state.ctx, title, rect, opt, opened);
}

ui_button :: proc(title: string) -> ui.Result_Set {
    return ui.button(_state.ctx, title);
}

ui_layout_row :: proc(widths: []i32, height: i32 = 0) {
    ui.layout_row(_state.ctx, widths, height);
}

ui_label :: proc(text: string) {
    ui.label(_state.ctx, text);
}

ui_begin_panel :: proc(name: string, opt := ui.Options {}) {
    ui.begin_panel(_state.ctx, name, opt);
}

ui_end_panel :: proc() {
    ui.end_panel(_state.ctx);
}

ui_text :: proc(text: string) {
    ui.text(_state.ctx, text);
}

ui_get_current_container :: proc() -> ^ui.Container {
    return ui.get_current_container(_state.ctx);
}

ui_textbox :: proc(buf: []u8, textlen: ^int, opt := ui.Options{}) -> ui.Result_Set {
    return ui.textbox(_state.ctx, buf, textlen, opt);
}

ui_set_focus :: proc(id: ui.Id) {
    ui.set_focus(_state.ctx, id);
}

ui_checkbox :: proc(label: string, state: ^bool) -> (res: ui.Result_Set) {
    return ui.checkbox(_state.ctx, label, state);
}

ui_push_id_uintptr :: proc(ptr: uintptr) {
    ui.push_id_uintptr(_state.ctx, ptr);
}

ui_pop_id :: proc() {
    ui.pop_id(_state.ctx);
}

ui_get_context :: proc() -> ^ui.Context {
    return _state.ctx;
}

ui_draw_rect :: proc(rect: ui.Rect, color: ui.Color) {
    ui.draw_rect(_state.ctx, rect, color);
}

ui_get_layout :: proc() -> ^ui.Layout {
    return ui.get_layout(_state.ctx);
}

ui_layout_next :: proc() -> ui.Rect {
    return ui.layout_next(_state.ctx);
}

rect_with_offset :: proc(rect: ui.Rect, offset: math.Vector2i) -> ui.Rect {
    return { rect.x + offset.x, rect.y + offset.y, rect.w, rect.h };
}

ui_input_mouse_move :: proc(x: i32, y: i32) {
    // log.debugf("mouse_move: %v,%v", x, y);
    ui.input_mouse_move(x, y);
}
ui_input_mouse_down :: proc(x: i32, y: i32, button: u8) {
    switch button {
        case platform.BUTTON_LEFT:   ui.input_mouse_down(x, y, .LEFT);
        case platform.BUTTON_MIDDLE: ui.input_mouse_down(x, y, .MIDDLE);
        case platform.BUTTON_RIGHT:  ui.input_mouse_down(x, y, .RIGHT);
    }
}
ui_input_mouse_up :: proc(x: i32, y: i32, button: u8) {
    switch button {
        case platform.BUTTON_LEFT:   ui.input_mouse_up(x, y, .LEFT);
        case platform.BUTTON_MIDDLE: ui.input_mouse_up(x, y, .MIDDLE);
        case platform.BUTTON_RIGHT:  ui.input_mouse_up(x, y, .RIGHT);
    }
}
ui_input_text :: ui.input_text;
ui_input_scroll :: ui.input_scroll;
ui_input_key_down :: proc(keycode: platform.Keycode) {
    #partial switch keycode {
        case .LSHIFT:    ui.input_key_down(.SHIFT);
        case .RSHIFT:    ui.input_key_down(.SHIFT);
        case .LCTRL:     ui.input_key_down(.CTRL);
        case .RCTRL:     ui.input_key_down(.CTRL);
        case .LALT:      ui.input_key_down(.ALT);
        case .RALT:      ui.input_key_down(.ALT);
        case .RETURN:    ui.input_key_down(.RETURN);
        case .KP_ENTER:  ui.input_key_down(.RETURN);
        case .BACKSPACE: ui.input_key_down(.BACKSPACE);
    }
}
ui_input_key_up :: proc(keycode: platform.Keycode) {
    #partial switch keycode {
        case .LSHIFT:    ui.input_key_up(.SHIFT);
        case .RSHIFT:    ui.input_key_up(.SHIFT);
        case .LCTRL:     ui.input_key_up(.CTRL);
        case .RCTRL:     ui.input_key_up(.CTRL);
        case .LALT:      ui.input_key_up(.ALT);
        case .RALT:      ui.input_key_up(.ALT);
        case .RETURN:    ui.input_key_up(.RETURN);
        case .KP_ENTER:  ui.input_key_up(.RETURN);
        case .BACKSPACE: ui.input_key_up(.BACKSPACE);
    }
}
