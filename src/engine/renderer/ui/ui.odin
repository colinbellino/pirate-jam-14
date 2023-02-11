package engine_ui

import log "core:log"
import mu "vendor:microui"

import renderer "../../renderer";

Options :: mu.Options;
Opt :: mu.Opt;
Color :: mu.Color;
Mouse :: mu.Mouse;
Key :: mu.Key;
Result_Set :: mu.Result_Set;
Context :: mu.Context;
Rect :: mu.Rect;

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

State :: struct {
    ctx:                mu.Context,
    atlas_texture:      ^renderer.Texture,
}

@private _state: ^State;

init :: proc(state: ^State) -> (ok: bool) {
    _state = state;

    atlas_texture, _, texture_ok := renderer.create_texture(u32(renderer.PixelFormatEnum.RGBA32), .TARGET, mu.DEFAULT_ATLAS_WIDTH, mu.DEFAULT_ATLAS_HEIGHT);
    if texture_ok == false {
        log.error("Couldn't create atlas_texture.");
        return;
    }
    _state.atlas_texture = atlas_texture;

    blend_error := renderer.set_texture_blend_mode(_state.atlas_texture, .BLEND);
    if blend_error > 0 {
        log.errorf("Couldn't set_blend_mode: %v", blend_error);
        return;
    }

    pixels := make([][4]u8, mu.DEFAULT_ATLAS_WIDTH*mu.DEFAULT_ATLAS_HEIGHT);
    defer delete(pixels);
    for alpha, i in mu.default_atlas_alpha {
        pixels[i].rgb = 0xff;
        pixels[i].a   = alpha;
    }

    update_error := renderer.update_texture(_state.atlas_texture, nil, raw_data(pixels), 4*mu.DEFAULT_ATLAS_WIDTH);
    if update_error > 0 {
        log.errorf("Couldn't update_texture: %v", update_error);
        return;
    }

    mu.init(&_state.ctx);
    _state.ctx.text_width = mu.default_atlas_text_width;
    _state.ctx.text_height = mu.default_atlas_text_height;

    ok = true;
    return;
}

process_ui_commands :: proc(rend: ^renderer.Renderer) {
    command_backing: ^mu.Command;
    for variant in mu.next_command_iterator(&_state.ctx, &command_backing) {
        switch cmd in variant {
            case ^mu.Command_Text: {
                dst := renderer.Rect{cmd.pos.x, cmd.pos.y, 0, 0};
                for ch in cmd.str do if ch&0xc0 != 0x80 {
                    r := min(int(ch), 127);
                    src := mu.default_atlas[mu.DEFAULT_ATLAS_FONT + r];
                    ui_render_atlas_texture(rend, &dst, src, cmd.color);
                    dst.x += dst.w;
                }
            }
            case ^mu.Command_Rect: {
                renderer.draw_fill_rect(&{cmd.rect.x, cmd.rect.y, cmd.rect.w, cmd.rect.h}, renderer.Color(cmd.color));
            }
            case ^mu.Command_Icon: {
                src := mu.default_atlas[cmd.id];
                x := cmd.rect.x + (cmd.rect.w - src.w)/2;
                y := cmd.rect.y + (cmd.rect.h - src.h)/2;
                ui_render_atlas_texture(rend, &{x, y, 0, 0}, src, cmd.color);
            }
            case ^mu.Command_Clip:
                renderer.set_clip_rect(&{cmd.rect.x, cmd.rect.y, cmd.rect.w, cmd.rect.h});
            case ^mu.Command_Jump:
                unreachable();
        }
    }
}

ui_render_atlas_texture :: proc(rend: ^renderer.Renderer, dst: ^renderer.Rect, src: Rect, color: Color) {
    dst.w = src.w;
    dst.h = src.h;

    renderer.draw_texture(_state.atlas_texture, &{src.x, src.y, src.w, src.h}, dst, renderer.Color(color))
}

draw_begin :: proc() {
    mu.begin(&_state.ctx);
}
draw_end :: proc() {
    mu.end(&_state.ctx);
}

input_mouse_move :: proc(x: i32, y: i32) {
    mu.input_mouse_move(&_state.ctx, x, y);
}

input_scroll :: proc(x: i32, y: i32) {
    mu.input_scroll(&_state.ctx, x, y);
}

input_text :: proc(text: string) {
    mu.input_text(&_state.ctx, text);
}

input_mouse_down :: proc(x: i32, y: i32, button: Mouse) {
    mu.input_mouse_down(&_state.ctx, x, y, button);
}
input_mouse_up :: proc(x: i32, y: i32, button: Mouse) {
    mu.input_mouse_up(&_state.ctx, x, y, button);
}

input_key_down :: proc(key: Key) {
    mu.input_key_down(&_state.ctx, key);
}
input_key_up :: proc(key: Key) {
    mu.input_key_up(&_state.ctx, key);
}

u8_slider :: proc(val: ^u8, lo, hi: u8) -> (res: Result_Set) {
    mu.push_id(&_state.ctx, uintptr(val));

    @static tmp: mu.Real;
    tmp = mu.Real(val^);
    res = mu.slider(&_state.ctx, &tmp, mu.Real(lo), mu.Real(hi), 0, "%.0f", {.ALIGN_CENTER});
    val^ = u8(tmp);
    mu.pop_id(&_state.ctx);
    return;
}
