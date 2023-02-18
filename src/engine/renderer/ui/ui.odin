package engine_ui

import "core:log"
import "core:runtime"
import mu "vendor:microui"

import renderer "../../renderer";
import math "../../math";

Renderer :: renderer.Renderer;
Options :: mu.Options;
Container :: mu.Container;
Opt :: mu.Opt;
Color :: mu.Color;
Mouse :: mu.Mouse;
Key :: mu.Key;
Result_Set :: mu.Result_Set;
Context :: mu.Context;
Rect :: mu.Rect;
Id :: mu.Id;
Layout :: mu.Layout;

UI_State :: struct {
    renderer_state:     ^renderer.Renderer_State,
    ctx:                mu.Context,
    atlas_texture:      ^renderer.Texture,
    rendering_offset:   ^math.Vector2i,
    hovered:            bool,
}

@private _state: ^UI_State;
@private _allocator: runtime.Allocator;

init :: proc(renderer_state: ^renderer.Renderer_State, allocator: runtime.Allocator) -> (state: ^UI_State, ok: bool) {
    context.allocator = allocator;
    _allocator = allocator;
    _state = new(UI_State);
    _state.rendering_offset = &renderer_state.rendering_offset;
    state = _state;

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
    // log.info("init: OK");
    return;
}

process_commands :: proc() {
    command_backing: ^mu.Command;

    for variant in mu.next_command_iterator(&_state.ctx, &command_backing) {
        switch cmd in variant {
            case ^mu.Command_Text: {
                destination := Rect {
                    cmd.pos.x, cmd.pos.y,
                    0, 0,
                };
                for ch in cmd.str do if ch&0xc0 != 0x80 {
                    r := min(int(ch), 127);
                    source := mu.default_atlas[mu.DEFAULT_ATLAS_FONT + r];
                    render_atlas_texture(source, &destination, cmd.color);
                    destination.x += destination.w;
                }
            }
            case ^mu.Command_Rect: {
                renderer.draw_fill_rect_no_offset(&{cmd.rect.x, cmd.rect.y, cmd.rect.w, cmd.rect.h}, renderer.Color(cmd.color));
            }
            case ^mu.Command_Icon: {
                source := mu.default_atlas[cmd.id];
                x := i32(cmd.rect.x) + (cmd.rect.w - source.w) / 2;
                y := i32(cmd.rect.y) + (cmd.rect.h - source.h) / 2;
                render_atlas_texture(source, &{ x, y, 0, 0 }, cmd.color);
            }
            case ^mu.Command_Clip:
                renderer.set_clip_rect(&{ cmd.rect.x, cmd.rect.y, cmd.rect.w, cmd.rect.h });
            case ^mu.Command_Jump:
                unreachable();
        }
    }
}

render_atlas_texture :: proc(source: Rect, destination: ^Rect, color: Color) {
    destination.w = source.w;
    destination.h = source.h;
    renderer.draw_texture_no_offset(_state.atlas_texture, &{ source.x, source.y, source.w, source.h }, &{ f32(destination.x), f32(destination.y), f32(destination.w), f32(destination.h) }, 1, renderer.Color(color));
}

is_hovered :: proc() -> bool {
    return _state.hovered;
}

draw_begin :: proc() {
    mu.begin(&_state.ctx);
}
draw_end :: proc() {
    mu.end(&_state.ctx);
    _state.hovered = false;
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

mouse_over :: proc(rect: Rect) -> bool {
    return mu.mouse_over(&_state.ctx, rect);
}

begin_window :: proc(title: string, rect: Rect, opt := Options{}) -> bool {
    return mu.begin_window(&_state.ctx, title, rect, opt);
}

@(deferred_in_out=scoped_end_window)
window :: proc(title: string, rect: Rect, opt: Options = {}) -> bool {
    final_rect := rect_with_offset(rect, _state.rendering_offset^);
    opened := begin_window(title, final_rect, opt);
    if mouse_over(final_rect) {
        _state.hovered = true;
    }
    return opened;
}

@(private="file")
scoped_end_window :: proc(title: string, rect: Rect, opt: Options, opened: bool) {
    mu.scoped_end_window(&_state.ctx, title, rect, opt, opened);
}

button :: proc(title: string) -> Result_Set {
    return mu.button(&_state.ctx, title);
}

layout_row :: proc(widths: []i32, height: i32 = 0) {
    mu.layout_row(&_state.ctx, widths, height);
}

label :: proc(text: string) {
    mu.label(&_state.ctx, text);
}

begin_panel :: proc(name: string, opt := Options {}) {
    mu.begin_panel(&_state.ctx, name, opt);
}

end_panel :: proc() {
    mu.end_panel(&_state.ctx);
}

text :: proc(text: string) {
    mu.text(&_state.ctx, text);
}

get_current_container :: proc() -> ^Container {
    return mu.get_current_container(&_state.ctx);
}

textbox :: proc(buf: []u8, textlen: ^int, opt := Options{}) -> Result_Set {
    return mu.textbox(&_state.ctx, buf, textlen, opt);
}

set_focus :: proc(id: Id) {
    mu.set_focus(&_state.ctx, id);
}

checkbox :: proc(label: string, state: ^bool) -> (res: Result_Set) {
    return mu.checkbox(&_state.ctx, label, state);
}

push_id_uintptr :: proc(ptr: uintptr) {
    mu.push_id_uintptr(&_state.ctx, ptr);
}

pop_id :: proc() {
    mu.pop_id(&_state.ctx);
}

get_context :: proc() -> ^Context {
    return &_state.ctx;
}

draw_rect :: proc(rect: Rect, color: Color) {
    mu.draw_rect(&_state.ctx, rect, color);
}

get_layout :: proc() -> ^Layout {
    return mu.get_layout(&_state.ctx);
}

layout_next :: proc() -> Rect {
    return mu.layout_next(&_state.ctx);
}

progress_bar :: proc(progress: f32, height: i32, color: Color = { 255, 255, 0, 255 }, bg_color: Color = { 10, 10, 10, 255 }) {
    layout_row({ -1 }, 5);
    layout := get_layout();
    next_layout_rect := layout_next();
    draw_rect({ next_layout_rect.x + 0, next_layout_rect.y + 0, next_layout_rect.w - 5, height }, bg_color);
    draw_rect({ next_layout_rect.x + 0, next_layout_rect.y + 0, i32(progress * f32(next_layout_rect.w - 5)), height }, color);
}

rect_with_offset :: proc(rect: Rect, offset: math.Vector2i) -> Rect {
    return { rect.x + offset.x, rect.y + offset.y, rect.w, rect.h };
}
