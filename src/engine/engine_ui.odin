package engine

import "core:log"
import mu "vendor:microui"

Options :: mu.Options;
Container :: mu.Container;
Opt :: mu.Opt;
Mouse :: mu.Mouse;
Key :: mu.Key;
Result_Set :: mu.Result_Set;
Context :: mu.Context;
Id :: mu.Id;
Layout :: mu.Layout;

UI_State :: struct {
    ctx:                mu.Context,
    atlas_texture:      ^Texture,
    rendering_offset:   ^Vector2i,
    hovered:            bool,
}

ui_init :: proc(renderer_state: ^Renderer_State) -> (ui_state: ^UI_State, ok: bool) {
    context.allocator = renderer_state.allocator;
    ui_state = new(UI_State);
    ui_state.rendering_offset = &renderer_state.rendering_offset;

    atlas_texture, _, texture_ok := create_texture(renderer_state, u32(PixelFormatEnum.RGBA32), .TARGET, mu.DEFAULT_ATLAS_WIDTH, mu.DEFAULT_ATLAS_HEIGHT);
    if texture_ok == false {
        log.error("Couldn't create atlas_texture.");
        return;
    }
    ui_state.atlas_texture = atlas_texture;

    blend_error := set_texture_blend_mode(renderer_state, ui_state.atlas_texture, .BLEND);
    if blend_error > 0 {
        log.errorf("Couldn't set_blend_mode: %v", blend_error);
        return;
    }

    pixels := make([][4]u8, mu.DEFAULT_ATLAS_WIDTH * mu.DEFAULT_ATLAS_HEIGHT);
    defer delete(pixels);
    for alpha, i in mu.default_atlas_alpha {
        pixels[i].rgb = 0xff;
        pixels[i].a   = alpha;
    }

    update_error := update_texture(renderer_state, ui_state.atlas_texture, nil, raw_data(pixels), 4 * mu.DEFAULT_ATLAS_WIDTH);
    if update_error > 0 {
        log.errorf("Couldn't update_texture: %v", update_error);
        return;
    }

    mu.init(&ui_state.ctx);
    ui_state.ctx.text_width = mu.default_atlas_text_width;
    ui_state.ctx.text_height = mu.default_atlas_text_height;

    renderer_state.ui_state = ui_state;

    ok = true;
    return;
}

ui_process_commands :: proc(renderer_state: ^Renderer_State) {
    // fmt.print("ui_process_commands -> ")
    command_backing: ^mu.Command;

    for variant in mu.next_command_iterator(&renderer_state.ui_state.ctx, &command_backing) {
        switch cmd in variant {
            case ^mu.Command_Text: {
                destination := mu.Rect {
                    cmd.pos.x, cmd.pos.y,
                    0, 0,
                };
                for ch in cmd.str do if (ch & 0xc0) != 0x80 {
                    r := min(int(ch), 127);
                    source := mu.default_atlas[mu.DEFAULT_ATLAS_FONT + r];
                    ui_render_atlas_texture(renderer_state, source, &destination, cmd.color);
                    destination.x += destination.w;
                }
            }
            case ^mu.Command_Rect: {
                draw_fill_rect_no_offset(renderer_state, &{cmd.rect.x, cmd.rect.y, cmd.rect.w, cmd.rect.h}, Color(cmd.color));
            }
            case ^mu.Command_Icon: {
                source := mu.default_atlas[cmd.id];
                x := i32(cmd.rect.x) + (cmd.rect.w - source.w) / 2;
                y := i32(cmd.rect.y) + (cmd.rect.h - source.h) / 2;
                ui_render_atlas_texture(renderer_state, source, &{ x, y, 0, 0 }, cmd.color);
            }
            case ^mu.Command_Clip:
                set_clip_rect(renderer_state, &{ cmd.rect.x, cmd.rect.y, cmd.rect.w, cmd.rect.h });
            case ^mu.Command_Jump:
                unreachable();
        }
    }
}

@(private="file")
ui_render_atlas_texture :: proc(renderer_state: ^Renderer_State, source: mu.Rect, destination: ^mu.Rect, color: mu.Color) {
    destination.w = source.w;
    destination.h = source.h;
    draw_texture_no_offset(renderer_state, renderer_state.ui_state.atlas_texture, &{ source.x, source.y, source.w, source.h }, &{ f32(destination.x), f32(destination.y), f32(destination.w), f32(destination.h) }, 1, Color(color));
}

ui_is_hovered :: proc(renderer_state: ^Renderer_State) -> bool {
    return renderer_state.ui_state.hovered;
}

// begin -> draw -> end -> process_commands -> present
ui_draw_begin :: proc(renderer_state: ^Renderer_State) {
    // fmt.print("ui_draw_begin -> ")
    mu.begin(&renderer_state.ui_state.ctx);
}
ui_draw_end :: proc(renderer_state: ^Renderer_State) {
    // fmt.print("ui_draw_end -> ")
    mu.end(&renderer_state.ui_state.ctx);
    renderer_state.ui_state.hovered = false;
}

ui_input_mouse_move :: proc(renderer_state: ^Renderer_State, x: i32, y: i32) {
    mu.input_mouse_move(&renderer_state.ui_state.ctx, x, y);
}

ui_input_scroll :: proc(renderer_state: ^Renderer_State, x: i32, y: i32) {
    mu.input_scroll(&renderer_state.ui_state.ctx, x, y);
}

ui_input_text :: proc(renderer_state: ^Renderer_State, text: string) {
    mu.input_text(&renderer_state.ui_state.ctx, text);
}

ui_input_mouse_down :: proc(renderer_state: ^Renderer_State, x: i32, y: i32, button: Mouse) {
    mu.input_mouse_down(&renderer_state.ui_state.ctx, x, y, button);
}
ui_input_mouse_up :: proc(renderer_state: ^Renderer_State, x: i32, y: i32, button: Mouse) {
    mu.input_mouse_up(&renderer_state.ui_state.ctx, x, y, button);
}

ui_input_key_down :: proc(renderer_state: ^Renderer_State, key: Key) {
    mu.input_key_down(&renderer_state.ui_state.ctx, key);
}
ui_input_key_up :: proc(renderer_state: ^Renderer_State, key: Key) {
    mu.input_key_up(&renderer_state.ui_state.ctx, key);
}

ui_u8_slider :: proc(renderer_state: ^Renderer_State, val: ^u8, lo, hi: u8) -> (res: Result_Set) {
    mu.push_id(&renderer_state.ui_state.ctx, uintptr(val));

    @static tmp: mu.Real;
    tmp = mu.Real(val^);
    res = mu.slider(&renderer_state.ui_state.ctx, &tmp, mu.Real(lo), mu.Real(hi), 0, "%.0f", {.ALIGN_CENTER});
    val^ = u8(tmp);
    mu.pop_id(&renderer_state.ui_state.ctx);
    return;
}

ui_mouse_over :: proc(renderer_state: ^Renderer_State, rect: Rect, opt: Options) -> bool {
    if .NO_INTERACT in opt {
        return false;
    }
    return mu.mouse_over(&renderer_state.ui_state.ctx, cast(mu.Rect) rect);
}

ui_begin_window :: proc(renderer_state: ^Renderer_State, title: string, rect: Rect, opt := Options{}) -> bool {
    return mu.begin_window(&renderer_state.ui_state.ctx, title, cast(mu.Rect) rect, opt);
}

@(deferred_in_out=ui_scoped_end_window)
ui_window :: proc(renderer_state: ^Renderer_State, title: string, rect: Rect, opt: Options = {}) -> bool {
    final_rect := ui_rect_with_offset(rect, renderer_state.ui_state.rendering_offset^);
    opened := ui_begin_window(renderer_state, title, cast(Rect) final_rect, opt);
    if opened {
        if ui_mouse_over(renderer_state, final_rect, opt) {
            renderer_state.ui_state.hovered = true;
        }
    }
    return opened;
}

@(private="file")
ui_scoped_end_window :: proc(renderer_state: ^Renderer_State, title: string, rect: Rect, opt: Options, opened: bool) {
    if opened {
        mu.scoped_end_window(&renderer_state.ui_state.ctx, title, cast(mu.Rect) rect, opt, opened);
    }
}

ui_button :: proc(renderer_state: ^Renderer_State, title: string) -> Result_Set {
    return mu.button(&renderer_state.ui_state.ctx, title);
}

ui_layout_row :: proc(renderer_state: ^Renderer_State, widths: []i32, height: i32 = 0) {
    mu.layout_row(&renderer_state.ui_state.ctx, widths, height);
}

ui_label :: proc(renderer_state: ^Renderer_State, text: string) {
    mu.label(&renderer_state.ui_state.ctx, text);
}

ui_begin_panel :: proc(renderer_state: ^Renderer_State, name: string, opt := Options {}) {
    mu.begin_panel(&renderer_state.ui_state.ctx, name, opt);
}

ui_end_panel :: proc(renderer_state: ^Renderer_State) {
    mu.end_panel(&renderer_state.ui_state.ctx);
}

ui_text :: proc(renderer_state: ^Renderer_State, text: string) {
    mu.text(&renderer_state.ui_state.ctx, text);
}

ui_get_current_container :: proc(renderer_state: ^Renderer_State) -> ^Container {
    return mu.get_current_container(&renderer_state.ui_state.ctx);
}

ui_textbox :: proc(renderer_state: ^Renderer_State, buf: []u8, textlen: ^int, opt := Options{}) -> Result_Set {
    return mu.textbox(&renderer_state.ui_state.ctx, buf, textlen, opt);
}

ui_set_focus :: proc(renderer_state: ^Renderer_State, id: Id) {
    mu.set_focus(&renderer_state.ui_state.ctx, id);
}

ui_checkbox :: proc(renderer_state: ^Renderer_State, label: string, state: ^bool) -> (res: Result_Set) {
    return mu.checkbox(&renderer_state.ui_state.ctx, label, state);
}

ui_push_id_uintptr :: proc(renderer_state: ^Renderer_State, ptr: uintptr) {
    mu.push_id_uintptr(&renderer_state.ui_state.ctx, ptr);
}

ui_pop_id :: proc(renderer_state: ^Renderer_State) {
    mu.pop_id(&renderer_state.ui_state.ctx);
}

ui_get_context :: proc(renderer_state: ^Renderer_State) -> ^Context {
    return &renderer_state.ui_state.ctx;
}

ui_draw_rect :: proc(renderer_state: ^Renderer_State, rect: Rect, color: Color) {
    mu.draw_rect(&renderer_state.ui_state.ctx, cast(mu.Rect) rect, cast(mu.Color) color);
}

ui_get_layout :: proc(renderer_state: ^Renderer_State) -> ^Layout {
    return mu.get_layout(&renderer_state.ui_state.ctx);
}

ui_layout_next :: proc(renderer_state: ^Renderer_State) -> Rect {
    return cast(Rect) mu.layout_next(&renderer_state.ui_state.ctx);
}

ui_progress_bar :: proc(renderer_state: ^Renderer_State, progress: f32, height: i32, color: Color = { 255, 255, 0, 255 }, bg_color: Color = { 10, 10, 10, 255 }) {
    ui_layout_row(renderer_state, { -1 }, 5);
    next_layout_rect := ui_layout_next(renderer_state);
    ui_draw_rect(renderer_state, { next_layout_rect.x + 0, next_layout_rect.y + 0, next_layout_rect.w - 5, height }, bg_color);
    ui_draw_rect(renderer_state, { next_layout_rect.x + 0, next_layout_rect.y + 0, i32(progress * f32(next_layout_rect.w - 5)), height }, color);
}

ui_graph :: proc(renderer_state: ^Renderer_State, values: []f64, width: i32, height: i32, max_value: f64, current: i32, current_color: Color = { 255, 0, 0, 255 }, bg_color: Color = { 10, 10, 10, 0 }) {
    base := ui_layout_next(renderer_state);
    bar_width := i32(f32(width) / f32(len(values) - 1));

    if bg_color.a > 0 {
        ui_draw_rect(renderer_state, { base.x, base.y, base.w, height }, bg_color);
    }

    for value, index in values {
        position_x := i32(index) - current;
        if position_x < 0 { // Loop around when it reach the left of the graph
            position_x = i32(len(values)) + position_x;
        }
        proportion : f64 = min(value / max_value, 1.0);
        // color := Color { u8(proportion * f64(255)), 255, 0, 255 };

        ui_draw_rect(renderer_state, {
            base.x + position_x * bar_width, base.y + i32((1.0 - proportion) * f64(height)),
            bar_width, max(i32(proportion * f64(height)), 1),
        }, current_color);
    }
}

ui_stacked_graph :: proc(renderer_state: ^Renderer_State, values: [][]f64, width: i32, height: i32, max_value: f64, current: i32, colors: []Color = {{ 255, 0, 0, 255 }}, bg_color: Color = { 10, 10, 10, 0 }) {
    base := ui_layout_next(renderer_state);
    bar_width := i32(f32(width) / f32(len(values) - 1));
    bar_margin : i32 = 1;

    if bg_color.a > 0 {
        ui_draw_rect(renderer_state, { base.x, base.y, width, height }, bg_color);
    }

    for snapshot_value, snapshot_index in values {
        stack_y : i32 = 0;
        for value, block_index in snapshot_value {
            current_color := colors[block_index % len(colors)];
            proportion : f64 = min(value / max_value, 1.0);
            position_x := i32(snapshot_index) - current;
            if position_x < 0 { // Loop around when it reach the left of the graph
                position_x = i32(len(values)) + position_x;
            }

            // bar_height := max(i32(proportion * f64(height)), 1);
            bar_height := i32(proportion * f64(height));
            ui_draw_rect(renderer_state, {
                base.x + position_x * bar_width, base.y - stack_y + i32((1.0 - proportion) * f64(height)),
                bar_width - bar_margin, bar_height,
            }, current_color);
            stack_y += bar_height;
        }
    }
}

@(private="file")
ui_rect_with_offset :: proc(rect: Rect, offset: Vector2i) -> Rect {
    return { rect.x + offset.x, rect.y + offset.y, rect.w, rect.h };
}

cast_color :: proc(color: Color) -> mu.Color {
    return cast(mu.Color) color;
}
