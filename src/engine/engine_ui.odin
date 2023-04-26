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
Icon :: mu.Icon;

UI_State :: struct {
    ctx:                mu.Context,
    atlas_texture:      ^Texture,
    rendering_offset:   ^Vector2i,
    hovered:            bool,
}

ui_init :: proc(renderer: ^Renderer_State) -> (ui: ^UI_State, ok: bool) {
    context.allocator = renderer.allocator;
    ui = new(UI_State);
    ui.rendering_offset = &renderer.rendering_offset;

    atlas_texture, _, texture_ok := create_texture(renderer, u32(PixelFormatEnum.RGBA32), .TARGET, mu.DEFAULT_ATLAS_WIDTH, mu.DEFAULT_ATLAS_HEIGHT);
    if texture_ok != true {
        log.error("Couldn't create atlas_texture.");
        return;
    }
    ui.atlas_texture = atlas_texture;

    blend_error := set_texture_blend_mode(renderer, ui.atlas_texture, .BLEND);
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

    update_error := update_texture(renderer, ui.atlas_texture, nil, raw_data(pixels), 4 * mu.DEFAULT_ATLAS_WIDTH);
    if update_error > 0 {
        log.errorf("Couldn't update_texture: %v", update_error);
        return;
    }

    mu.init(&ui.ctx);
    ui.ctx.text_width = mu.default_atlas_text_width;
    ui.ctx.text_height = mu.default_atlas_text_height;

    ui = ui;

    ok = true;
    return;
}

ui_process_commands :: proc(renderer: ^Renderer_State, ui: ^UI_State) {
    command_backing: ^mu.Command;

    for variant in mu.next_command_iterator(&ui.ctx, &command_backing) {
        switch cmd in variant {
            case ^mu.Command_Text: {
                destination := mu.Rect {
                    cmd.pos.x, cmd.pos.y,
                    0, 0,
                };
                for ch in cmd.str do if (ch & 0xc0) != 0x80 {
                    r := min(int(ch), 127);
                    source := mu.default_atlas[mu.DEFAULT_ATLAS_FONT + r];
                    ui_render_atlas_texture(renderer, ui, source, &destination, cmd.color);
                    destination.x += destination.w;
                }
            }
            case ^mu.Command_Rect: {
                destination := make_rect_f32(cmd.rect.x, cmd.rect.y, cmd.rect.w, cmd.rect.h);
                draw_fill_rect_no_offset(renderer, &destination, Color(cmd.color));
            }
            case ^mu.Command_Icon: {
                source := mu.default_atlas[cmd.id];
                x := i32(cmd.rect.x) + (cmd.rect.w - source.w) / 2;
                y := i32(cmd.rect.y) + (cmd.rect.h - source.h) / 2;
                ui_render_atlas_texture(renderer, ui, source, &{ x, y, 0, 0 }, cmd.color);
            }
            case ^mu.Command_Clip:
                set_clip_rect(renderer, &{ cmd.rect.x, cmd.rect.y, cmd.rect.w, cmd.rect.h });
            case ^mu.Command_Jump:
                unreachable();
        }
    }
}

@(private="file")
ui_render_atlas_texture :: proc(renderer: ^Renderer_State, ui: ^UI_State, source: mu.Rect, destination: ^mu.Rect, color: mu.Color) {
    scale := renderer.rendering_scale;

    destination.w = source.w;
    destination.h = source.h;

    renderer.rendering_scale = 1;
    draw_texture_no_offset(
        renderer, ui.atlas_texture,
        &{ source.x, source.y, source.w, source.h },
        &{ f32(destination.x), f32(destination.y), f32(destination.w), f32(destination.h) },
        Color(color),
    );
    renderer.rendering_scale = scale;
}

ui_is_hovered :: proc(ui: ^UI_State) -> bool {
    return ui.hovered;
}

// begin -> draw -> end -> process_commands -> present
ui_begin :: proc(ui: ^UI_State) {
    mu.begin(&ui.ctx);
}
ui_end :: proc(ui: ^UI_State) {
    mu.end(&ui.ctx);
    ui.hovered = false;
}

ui_input_mouse_move :: proc(ui: ^UI_State, x: i32, y: i32) {
    mu.input_mouse_move(&ui.ctx, x, y);
}

ui_input_scroll :: proc(ui: ^UI_State, x: i32, y: i32) {
    mu.input_scroll(&ui.ctx, x, -y);
}

ui_input_text :: proc(ui: ^UI_State, text: string) {
    mu.input_text(&ui.ctx, text);
}

ui_input_mouse_down :: proc(ui: ^UI_State, x: i32, y: i32, button: Mouse) {
    mu.input_mouse_down(&ui.ctx, x, y, button);
}
ui_input_mouse_up :: proc(ui: ^UI_State, x: i32, y: i32, button: Mouse) {
    mu.input_mouse_up(&ui.ctx, x, y, button);
}

ui_input_key_down :: proc(ui: ^UI_State, key: Key) {
    mu.input_key_down(&ui.ctx, key);
}
ui_input_key_up :: proc(ui: ^UI_State, key: Key) {
    mu.input_key_up(&ui.ctx, key);
}

ui_u8_slider :: proc(ui: ^UI_State, val: ^u8, lo, hi: u8) -> (res: Result_Set) {
    mu.push_id(&ui.ctx, uintptr(val));

    @static tmp: mu.Real;
    tmp = mu.Real(val^);
    res = mu.slider(&ui.ctx, &tmp, mu.Real(lo), mu.Real(hi), 0, "%.0f", {.ALIGN_CENTER});
    val^ = u8(tmp);
    mu.pop_id(&ui.ctx);
    return;
}

ui_mouse_over :: proc(ui: ^UI_State, rect: Rect, opt: Options) -> bool {
    if .NO_INTERACT in opt {
        return false;
    }
    return mu.mouse_over(&ui.ctx, cast(mu.Rect) rect);
}

ui_begin_window :: proc(ui: ^UI_State, title: string, rect: Rect, opt := Options{}) -> bool {
    return mu.begin_window(&ui.ctx, title, cast(mu.Rect) rect, opt);
}

@(deferred_in_out=ui_scoped_end_window)
ui_window :: proc(ui: ^UI_State, title: string, rect: Rect, opt: Options = {}) -> bool {
    // final_rect := ui_rect_with_offset(rect, renderer.rendering_offset);
    opened := ui_begin_window(ui, title, cast(Rect) rect, opt);
    if opened {
        if ui_mouse_over(ui, rect, opt) {
            ui.hovered = true;
        }
    }
    return opened;
}

@(private="file")
ui_scoped_end_window :: proc(ui: ^UI_State, title: string, rect: Rect, opt: Options, opened: bool) {
    if opened {
        mu.scoped_end_window(&ui.ctx, title, cast(mu.Rect) rect, opt, opened);
    }
}

ui_button :: proc(ui: ^UI_State, label: string, icon: Icon = .NONE) -> Result_Set {
    return mu.button(&ui.ctx, label);
}

ui_label :: proc(ui: ^UI_State, text: string) {
    mu.label(&ui.ctx, text);
}

ui_panel_begin :: proc(ui: ^UI_State, name: string, opt := Options {}) {
    mu.begin_panel(&ui.ctx, name, opt);
}

ui_panel_end :: proc(ui: ^UI_State) {
    mu.end_panel(&ui.ctx);
}

ui_text :: proc(ui: ^UI_State, text: string) {
    mu.text(&ui.ctx, text);
}

ui_get_current_container :: proc(ui: ^UI_State) -> ^Container {
    return mu.get_current_container(&ui.ctx);
}

ui_textbox :: proc(ui: ^UI_State, buf: []u8, textlen: ^int, opt := Options{}) -> Result_Set {
    return mu.textbox(&ui.ctx, buf, textlen, opt);
}

ui_set_focus :: proc(ui: ^UI_State, id: Id) {
    mu.set_focus(&ui.ctx, id);
}

ui_checkbox :: proc(ui: ^UI_State, label: string, state: ^bool) -> (res: Result_Set) {
    return mu.checkbox(&ui.ctx, label, state);
}

ui_push_id_uintptr :: proc(ui: ^UI_State, ptr: uintptr) {
    mu.push_id_uintptr(&ui.ctx, ptr);
}

ui_pop_id :: proc(ui: ^UI_State) {
    mu.pop_id(&ui.ctx);
}

ui_get_context :: proc(ui: ^UI_State) -> ^Context {
    return &ui.ctx;
}

ui_draw_rect :: proc(ui: ^UI_State, rect: Rect, color: Color) {
    mu.draw_rect(&ui.ctx, cast(mu.Rect) rect, cast(mu.Color) color);
}

ui_get_layout :: proc(ui: ^UI_State) -> ^Layout {
    return mu.get_layout(&ui.ctx);
}

ui_layout_next :: proc(ui: ^UI_State) -> Rect {
    return cast(Rect) mu.layout_next(&ui.ctx);
}

ui_progress_bar :: proc(ui: ^UI_State, progress: f32, height: i32, color: Color = { 255, 255, 0, 255 }, bg_color: Color = { 10, 10, 10, 255 }) {
    ui_layout_row(ui, { -1 }, 5);
    next_layout_rect := ui_layout_next(ui);
    ui_draw_rect(ui, { next_layout_rect.x + 0, next_layout_rect.y + 0, next_layout_rect.w - 5, height }, bg_color);
    ui_draw_rect(ui, { next_layout_rect.x + 0, next_layout_rect.y + 0, i32(progress * f32(next_layout_rect.w - 5)), height }, color);
}

ui_graph :: proc(ui: ^UI_State, values: []f64, width: i32, height: i32, max_value: f64, current: i32, current_color: Color = { 255, 0, 0, 255 }, bg_color: Color = { 10, 10, 10, 0 }) {
    base := ui_layout_next(ui);
    bar_width := i32(f32(width) / f32(len(values) - 1));

    if bg_color.a > 0 {
        ui_draw_rect(ui, { base.x, base.y, base.w, height }, bg_color);
    }

    for value, index in values {
        position_x := i32(index) - current;
        if position_x < 0 { // Loop around when it reach the left of the graph
            position_x = i32(len(values)) + position_x;
        }
        proportion : f64 = min(value / max_value, 1.0);
        // color := Color { u8(proportion * f64(255)), 255, 0, 255 };

        ui_draw_rect(ui, {
            base.x + position_x * bar_width, base.y + i32((1.0 - proportion) * f64(height)),
            bar_width, max(i32(proportion * f64(height)), 1),
        }, current_color);
    }
}

ui_stacked_graph :: proc(ui: ^UI_State, values: [][]f64, width: i32, height: i32, max_value: f64, current: i32, colors: []Color = {{ 255, 0, 0, 255 }}, bg_color: Color = { 10, 10, 10, 0 }) {
    base := ui_layout_next(ui);
    bar_width := i32(f32(width) / f32(len(values) - 1));
    bar_margin : i32 = 1;

    if bg_color.a > 0 {
        ui_draw_rect(ui, { base.x, base.y, width, height }, bg_color);
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
            ui_draw_rect(ui, {
                base.x + position_x * bar_width, base.y - stack_y + i32((1.0 - proportion) * f64(height)),
                bar_width - bar_margin, bar_height,
            }, current_color);
            stack_y += bar_height;
        }
    }
}

ui_layout_row :: proc(ui: ^UI_State, widths: []i32, height: i32 = 0) {
    mu.layout_row(&ui.ctx, widths, height);
}
ui_layout_column :: proc(ui: ^UI_State) -> bool {
    return mu.layout_column(&ui.ctx);
}
ui_layout_width :: proc(ui: ^UI_State, width: i32) {
    mu.layout_width(&ui.ctx, width);
}

ui_header :: proc(ui: ^UI_State, label: string, opt := Options{}) -> Result_Set {
	return mu.header(&ui.ctx, label, opt);
}

@(deferred_in_out=ui_scoped_end_treenode)
ui_treenode :: proc(ui: ^UI_State, label: string, opt := Options{}) -> Result_Set {
	return ui_treenode_begin(ui, label, opt);
}
ui_scoped_end_treenode :: proc(ui: ^UI_State, label: string, opt: Options, result_set: Result_Set) {
	mu.scoped_end_treenode(&ui.ctx, label, opt, result_set);
}
ui_treenode_begin :: proc(ui: ^UI_State, label: string, opt := Options{}) -> Result_Set {
	return mu.begin_treenode(&ui.ctx, label, opt);
}
ui_treenode_end :: proc(ui: ^UI_State) {
	mu.end_treenode(&ui.ctx);
}

@(private="file")
ui_rect_with_offset :: proc(rect: Rect, offset: Vector2i) -> Rect {
    return { rect.x + offset.x, rect.y + offset.y, rect.w, rect.h };
}

cast_color :: proc(color: Color) -> mu.Color {
    return cast(mu.Color) color;
}
