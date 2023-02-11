package engine_ui

import "core:fmt"
import sdl "vendor:sdl2"
import mu "vendor:microui"

import logger "../../logger"
import renderer "../"

Options :: mu.Options;
Opt :: mu.Opt;
ColorType :: mu.Color_Type;

window :: mu.window;
header :: mu.header;
get_current_container :: mu.get_current_container;
layout_row :: mu.layout_row;
label :: mu.label;
checkbox :: mu.checkbox;
button :: mu.button;
layout_begin_column :: mu.layout_begin_column;
treenode :: mu.treenode;
layout_next :: mu.layout_next;
layout_end_column :: mu.layout_end_column;
text :: mu.text;
draw_rect :: mu.draw_rect;
draw_box :: mu.draw_box;
expand_rect :: mu.expand_rect;
draw_control_text :: mu.draw_control_text;
begin_panel :: mu.begin_panel;
end_panel :: mu.end_panel;
textbox :: mu.textbox;
set_focus :: mu.set_focus;

draw_begin :: proc() {
    mu.begin(&renderer.state.ui_context);
}
draw_end :: proc() {
    mu.end(&renderer.state.ui_context);
}

input_mouse_move :: proc(x: i32, y: i32) {
    mu.input_mouse_move(&renderer.state.ui_context, x, y);
}

input_scroll :: proc(x: i32, y: i32) {
    mu.input_scroll(&renderer.state.ui_context, x, y);
}

input_text :: proc(text: string) {
    mu.input_text(&renderer.state.ui_context, text);
}

input_mouse_down :: proc(x: i32, y: i32, button: mu.Mouse) {
    mu.input_mouse_down(&renderer.state.ui_context, x, y, button);
}
input_mouse_up :: proc(x: i32, y: i32, button: mu.Mouse) {
    mu.input_mouse_up(&renderer.state.ui_context, x, y, button);
}

input_key_down :: proc(key: mu.Key) {
    mu.input_key_down(&renderer.state.ui_context, key);
}
input_key_up :: proc(key: mu.Key) {
    mu.input_key_up(&renderer.state.ui_context, key);
}

u8_slider :: proc(val: ^u8, lo, hi: u8) -> (res: mu.Result_Set) {
    ctx := &renderer.state.ui_context;

    mu.push_id(ctx, uintptr(val));

    @static tmp: mu.Real;
    tmp = mu.Real(val^);
    res = mu.slider(ctx, &tmp, mu.Real(lo), mu.Real(hi), 0, "%.0f", {.ALIGN_CENTER});
    val^ = u8(tmp);
    mu.pop_id(ctx);
    return;
}
