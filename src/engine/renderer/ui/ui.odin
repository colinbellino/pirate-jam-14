package engine_ui

import "core:fmt"
import sdl "vendor:sdl2"
import mu "vendor:microui"

import logger "../../logger"
import renderer "../"

Options :: mu.Options;
Opt :: mu.Opt;
Color :: mu.Color;
Mouse :: mu.Mouse;
Key :: mu.Key;
Result_Set :: mu.Result_Set;
Context :: mu.Context;

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

input_mouse_down :: proc(x: i32, y: i32, button: Mouse) {
    mu.input_mouse_down(&renderer.state.ui_context, x, y, button);
}
input_mouse_up :: proc(x: i32, y: i32, button: Mouse) {
    mu.input_mouse_up(&renderer.state.ui_context, x, y, button);
}

input_key_down :: proc(key: Key) {
    mu.input_key_down(&renderer.state.ui_context, key);
}
input_key_up :: proc(key: Key) {
    mu.input_key_up(&renderer.state.ui_context, key);
}

u8_slider :: proc(val: ^u8, lo, hi: u8) -> (res: Result_Set) {
    ctx := &renderer.state.ui_context;

    mu.push_id(ctx, uintptr(val));

    @static tmp: mu.Real;
    tmp = mu.Real(val^);
    res = mu.slider(ctx, &tmp, mu.Real(lo), mu.Real(hi), 0, "%.0f", {.ALIGN_CENTER});
    val^ = u8(tmp);
    mu.pop_id(ctx);
    return;
}

// text_line :: proc(ctx: ^Context, text: string) {
//     text  := text
//     font  := ctx.style.font
//     color := ctx.style.colors[.TEXT]
//     layout_begin_column(ctx)
//     layout_row(ctx, {-1}, ctx.text_height(font))
//     for len(text) > 0 {
//         w:     i32
//         start: int
//         end:   int = len(text)
//         r := layout_next(ctx)
//         for ch, i in text {
//             if ch == ' ' || ch == '\n' {
//                 word := text[start:i]
//                 w += ctx.text_width(font, word)
//                 if w > r.w && start != 0 {
//                     end = start
//                     break
//                 }
//                 w += ctx.text_width(font, text[i:i+1])
//                 if ch == '\n' {
//                     end = i+1
//                     break
//                 }
//                 start = i+1
//             }
//         }
//         mu.draw_text(ctx, font, text[:end], mu.Vec2{r.x, r.y}, color)
//         text = text[end:]
//     }
//     layout_end_column(ctx)
// }
