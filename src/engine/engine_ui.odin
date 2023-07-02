package engine

import "core:log"
import mu "vendor:microui"

Options :: mu.Options
Container :: mu.Container
Opt :: mu.Opt
Mouse :: mu.Mouse
Key :: mu.Key
Result_Set :: mu.Result_Set
Context :: mu.Context
Id :: mu.Id
Layout :: mu.Layout
Icon :: mu.Icon

UI_State :: struct {
    ctx:                mu.Context,
    atlas_texture:      ^Texture,
    rendering_offset:   ^Vector2i32,
    hovered:            bool,
}

ui_init :: proc() -> (ok: bool) {
    profiler_zone("ui_init")
    context.allocator = _engine.allocator
    _engine.ui = new(UI_State)
    _engine.ui.rendering_offset = &_engine.renderer.rendering_offset

    atlas_texture, _, texture_ok := renderer_create_texture(u32(PixelFormatEnum.RGBA32), .TARGET, mu.DEFAULT_ATLAS_WIDTH, mu.DEFAULT_ATLAS_HEIGHT)
    if texture_ok != true {
        log.error("Couldn't create atlas_texture.")
        return
    }
    _engine.ui.atlas_texture = atlas_texture

    blend_error := renderer_set_texture_blend_mode(atlas_texture, .BLEND)
    if blend_error > 0 {
        log.errorf("Couldn't set_blend_mode: %v", blend_error)
        return
    }

    pixels := make([][4]u8, mu.DEFAULT_ATLAS_WIDTH * mu.DEFAULT_ATLAS_HEIGHT)
    defer delete(pixels)
    for alpha, i in mu.default_atlas_alpha {
        pixels[i].rgb = 0xff
        pixels[i].a   = alpha
    }

    update_error := renderer_update_texture(atlas_texture, nil, raw_data(pixels), 4 * mu.DEFAULT_ATLAS_WIDTH)
    if update_error > 0 {
        log.errorf("Couldn't renderer_update_texture: %v", update_error)
        return
    }

    mu.init(&_engine.ui.ctx)
    _engine.ui.ctx.text_width = mu.default_atlas_text_width
    _engine.ui.ctx.text_height = mu.default_atlas_text_height

    ok = true
    return
}

// ui_process_commands :: proc() {
//     if renderer_is_enabled() == false || _engine.ui == nil do return
//     command_backing: ^mu.Command

//     for variant in mu.next_command_iterator(&_engine.ui.ctx, &command_backing) {
//         switch cmd in variant {
//             case ^mu.Command_Text: {
//                 destination := mu.Rect {
//                     cmd.pos.x, cmd.pos.y,
//                     0, 0,
//                 }
//                 for ch in cmd.str do if (ch & 0xc0) != 0x80 {
//                     r := min(int(ch), 127)
//                     source := mu.default_atlas[mu.DEFAULT_ATLAS_FONT + r]
//                     _ui_render_atlas_texture(source, &destination, cmd.color)
//                     destination.x += destination.w
//                 }
//             }
//             case ^mu.Command_Rect: {
//                 destination := renderer_make_rect_f32(cmd.rect.x, cmd.rect.y, cmd.rect.w, cmd.rect.h)
//                 renderer_draw_fill_rect_no_offset(&destination, Color(cmd.color))
//             }
//             case ^mu.Command_Icon: {
//                 source := mu.default_atlas[cmd.id]
//                 x := i32(cmd.rect.x) + (cmd.rect.w - source.w) / 2
//                 y := i32(cmd.rect.y) + (cmd.rect.h - source.h) / 2
//                 _ui_render_atlas_texture(source, &{ x, y, 0, 0 }, cmd.color)
//             }
//             case ^mu.Command_Clip:
//                 renderer_set_clip_rect(&{ cmd.rect.x, cmd.rect.y, cmd.rect.w, cmd.rect.h })
//             case ^mu.Command_Jump:
//                 unreachable()
//         }
//     }
// }

// ui_is_hovered :: proc() -> bool {
//     return _engine.ui.hovered
// }

// // begin -> draw -> end -> process_commands -> present
// ui_begin :: proc() {
//     if renderer_is_enabled() == false || _engine.ui == nil do return
//     mu.begin(&_engine.ui.ctx)
// }
// ui_end :: proc() {
//     if renderer_is_enabled() == false || _engine.ui == nil do return
//     mu.end(&_engine.ui.ctx)
//     _engine.ui.hovered = false
// }

// ui_input_mouse_move :: proc(x: i32, y: i32) {
//     if renderer_is_enabled() == false || _engine.ui == nil do return
//     mu.input_mouse_move(&_engine.ui.ctx, x, y)
// }

// ui_input_scroll :: proc(x: i32, y: i32) {
//     if renderer_is_enabled() == false || _engine.ui == nil do return
//     mu.input_scroll(&_engine.ui.ctx, x, -y)
// }

// ui_input_text :: proc(text: string) {
//     if renderer_is_enabled() == false || _engine.ui == nil do return
//     mu.input_text(&_engine.ui.ctx, text)
// }

// ui_input_mouse_down :: proc(x: i32, y: i32, button: Mouse) {
//     if renderer_is_enabled() == false || _engine.ui == nil do return
//     mu.input_mouse_down(&_engine.ui.ctx, x, y, button)
// }
// ui_input_mouse_up :: proc(x: i32, y: i32, button: Mouse) {
//     if renderer_is_enabled() == false || _engine.ui == nil do return
//     mu.input_mouse_up(&_engine.ui.ctx, x, y, button)
// }

// ui_input_key_down :: proc(key: Key) {
//     if renderer_is_enabled() == false || _engine.ui == nil do return
//     mu.input_key_down(&_engine.ui.ctx, key)
// }
// ui_input_key_up :: proc(key: Key) {
//     if renderer_is_enabled() == false || _engine.ui == nil do return
//     mu.input_key_up(&_engine.ui.ctx, key)
// }

// ui_u8_slider :: proc(val: ^u8, lo, hi: u8) -> (res: Result_Set) {
//     if renderer_is_enabled() == false || _engine.ui == nil do return
//     mu.push_id(&_engine.ui.ctx, uintptr(val))

//     @static tmp: mu.Real
//     tmp = mu.Real(val^)
//     res = mu.slider(&_engine.ui.ctx, &tmp, mu.Real(lo), mu.Real(hi), 0, "%.0f", {.ALIGN_CENTER})
//     val^ = u8(tmp)
//     mu.pop_id(&_engine.ui.ctx)
//     return
// }

// ui_mouse_over :: proc(rect: Rect, opt: Options) -> (result: bool) {
//     if renderer_is_enabled() == false || _engine.ui == nil do return
//     if .NO_INTERACT in opt {
//         return false
//     }
//     return mu.mouse_over(&_engine.ui.ctx, cast(mu.Rect) rect)
// }

// ui_begin_window :: proc(title: string, rect: Rect, opt := Options{}) -> (result: bool) {
//     if renderer_is_enabled() == false || _engine.ui == nil do return
//     return mu.begin_window(&_engine.ui.ctx, title, cast(mu.Rect) rect, opt)
// }

// @(deferred_in_out=ui_scoped_end_window)
// ui_window :: proc(title: string, rect: Rect, opt: Options = {}) -> (result: bool) {
//     if renderer_is_enabled() == false || _engine.ui == nil do return
//     // final_rect := ui_rect_with_offset(rect, renderer.rendering_offset)
//     opened := ui_begin_window(title, cast(Rect) rect, opt)
//     if opened {
//         if ui_mouse_over(rect, opt) {
//             _engine.ui.hovered = true
//         }
//     }
//     return opened
// }

// @(private="file")
// ui_scoped_end_window :: proc(title: string, rect: Rect, opt: Options, opened: bool) {
//     if renderer_is_enabled() == false || _engine.ui == nil do return
//     if opened {
//         mu.scoped_end_window(&_engine.ui.ctx, title, cast(mu.Rect) rect, opt, opened)
//     }
// }

// ui_button :: proc(label: string, icon: Icon = .NONE) -> (result: Result_Set) {
//     if renderer_is_enabled() == false || _engine.ui == nil do return
//     return mu.button(&_engine.ui.ctx, label)
// }

// ui_label :: proc(text: string) {
//     if renderer_is_enabled() == false || _engine.ui == nil do return
//     mu.label(&_engine.ui.ctx, text)
// }

// ui_panel_begin :: proc(name: string, opt := Options {}) {
//     if renderer_is_enabled() == false || _engine.ui == nil do return
//     mu.begin_panel(&_engine.ui.ctx, name, opt)
// }

// ui_panel_end :: proc() {
//     if renderer_is_enabled() == false || _engine.ui == nil do return
//     mu.end_panel(&_engine.ui.ctx)
// }

// ui_text :: proc(text: string) {
//     if renderer_is_enabled() == false || _engine.ui == nil do return
//     mu.text(&_engine.ui.ctx, text)
// }

// ui_get_current_container :: proc() -> (result: ^Container) {
//     if renderer_is_enabled() == false || _engine.ui == nil do return
//     return mu.get_current_container(&_engine.ui.ctx)
// }

// ui_textbox :: proc(buf: []u8, textlen: ^int, opt := Options{}) -> (result: Result_Set) {
//     if renderer_is_enabled() == false || _engine.ui == nil do return
//     return mu.textbox(&_engine.ui.ctx, buf, textlen, opt)
// }

// ui_set_focus :: proc(id: Id) {
//     if renderer_is_enabled() == false || _engine.ui == nil do return
//     mu.set_focus(&_engine.ui.ctx, id)
// }

// ui_checkbox :: proc(label: string, state: ^bool) -> (res: Result_Set) {
//     if renderer_is_enabled() == false || _engine.ui == nil do return
//     return mu.checkbox(&_engine.ui.ctx, label, state)
// }

// ui_push_id_uintptr :: proc(ptr: uintptr) {
//     if renderer_is_enabled() == false || _engine.ui == nil do return
//     mu.push_id_uintptr(&_engine.ui.ctx, ptr)
// }

// ui_pop_id :: proc() {
//     if renderer_is_enabled() == false || _engine.ui == nil do return
//     mu.pop_id(&_engine.ui.ctx)
// }

// ui_get_context :: proc() -> (result: ^Context) {
//     if renderer_is_enabled() == false || _engine.ui == nil do return
//     return &_engine.ui.ctx
// }

// ui_draw_rect :: proc(rect: Rect, color: Color) {
//     if renderer_is_enabled() == false || _engine.ui == nil do return
//     mu.draw_rect(&_engine.ui.ctx, cast(mu.Rect) rect, cast(mu.Color) color)
// }

// ui_get_layout :: proc() -> (result: ^Layout) {
//     if renderer_is_enabled() == false || _engine.ui == nil do return
//     return mu.get_layout(&_engine.ui.ctx)
// }

// ui_layout_next :: proc() -> (result: Rect) {
//     if renderer_is_enabled() == false || _engine.ui == nil do return
//     return cast(Rect) mu.layout_next(&_engine.ui.ctx)
// }

// ui_progress_bar :: proc(progress: f32, height: i32, color: Color = { 255, 255, 0, 255 }, bg_color: Color = { 10, 10, 10, 255 }) {
//     if renderer_is_enabled() == false || _engine.ui == nil do return
//     ui_layout_row({ -1 }, 5)
//     next_layout_rect := ui_layout_next()
//     ui_draw_rect({ next_layout_rect.x + 0, next_layout_rect.y + 0, next_layout_rect.w - 5, height }, bg_color)
//     ui_draw_rect({ next_layout_rect.x + 0, next_layout_rect.y + 0, i32(progress * f32(next_layout_rect.w - 5)), height }, color)
// }

// ui_graph :: proc(values: []f64, width: i32, height: i32, max_value: f64, current: i32, current_color: Color = { 255, 0, 0, 255 }, bg_color: Color = { 10, 10, 10, 0 }) {
//     if renderer_is_enabled() == false || _engine.ui == nil do return
//     base := ui_layout_next()
//     bar_width := i32(f32(width) / f32(len(values) - 1))

//     if bg_color.a > 0 {
//         ui_draw_rect({ base.x, base.y, base.w, height }, bg_color)
//     }

//     for value, index in values {
//         position_x := i32(index) - current
//         if position_x < 0 { // Loop around when it reach the left of the graph
//             position_x = i32(len(values)) + position_x
//         }
//         proportion : f64 = min(value / max_value, 1.0)
//         // color := Color { u8(proportion * f64(255)), 255, 0, 255 }

//         ui_draw_rect({
//             base.x + position_x * bar_width, base.y + i32((1.0 - proportion) * f64(height)),
//             bar_width, max(i32(proportion * f64(height)), 1),
//         }, current_color)
//     }
// }

// ui_stacked_graph :: proc(values: [][]f64, width: i32, height: i32, max_value: f64, current: i32, colors: []Color = {{ 255, 0, 0, 255 }}, bg_color: Color = { 10, 10, 10, 0 }) {
//     if renderer_is_enabled() == false || _engine.ui == nil do return
//     base := ui_layout_next()
//     bar_width := i32(f32(width) / f32(len(values) - 1))
//     bar_margin : i32 = 1

//     if bg_color.a > 0 {
//         ui_draw_rect({ base.x, base.y, width, height }, bg_color)
//     }

//     for snapshot_value, snapshot_index in values {
//         stack_y : i32 = 0
//         for value, block_index in snapshot_value {
//             current_color := colors[block_index % len(colors)]
//             proportion : f64 = min(value / max_value, 1.0)
//             position_x := i32(snapshot_index) - current
//             if position_x < 0 { // Loop around when it reach the left of the graph
//                 position_x = i32(len(values)) + position_x
//             }

//             // bar_height := max(i32(proportion * f64(height)), 1)
//             bar_height := i32(proportion * f64(height))
//             ui_draw_rect({
//                 base.x + position_x * bar_width, base.y - stack_y + i32((1.0 - proportion) * f64(height)),
//                 bar_width - bar_margin, bar_height,
//             }, current_color)
//             stack_y += bar_height
//         }
//     }
// }

// ui_layout_row :: proc(widths: []i32, height: i32 = 0) {
//     if renderer_is_enabled() == false || _engine.ui == nil do return
//     mu.layout_row(&_engine.ui.ctx, widths, height)
// }
// ui_layout_column :: proc() -> (result: bool) {
//     if renderer_is_enabled() == false || _engine.ui == nil do return
//     return mu.layout_column(&_engine.ui.ctx)
// }
// ui_layout_width :: proc(width: i32) {
//     if renderer_is_enabled() == false || _engine.ui == nil do return
//     mu.layout_width(&_engine.ui.ctx, width)
// }

// ui_header :: proc(label: string, opt := Options{}) -> (result: Result_Set) {
//     if renderer_is_enabled() == false || _engine.ui == nil do return
//     return mu.header(&_engine.ui.ctx, label, opt)
// }

// @(deferred_in_out=ui_scoped_end_treenode)
// ui_treenode :: proc(label: string, opt := Options{}) -> (result: Result_Set) {
//     if renderer_is_enabled() == false || _engine.ui == nil do return
//     return ui_treenode_begin(label, opt)
// }
// ui_scoped_end_treenode :: proc(label: string, opt: Options, result_set: Result_Set) {
//     if renderer_is_enabled() == false || _engine.ui == nil do return
//     mu.scoped_end_treenode(&_engine.ui.ctx, label, opt, result_set)
// }
// ui_treenode_begin :: proc(label: string, opt := Options{}) -> (result: Result_Set) {
//     if renderer_is_enabled() == false || _engine.ui == nil do return
//     return mu.begin_treenode(&_engine.ui.ctx, label, opt)
// }
// ui_treenode_end :: proc() {
//     if renderer_is_enabled() == false || _engine.ui == nil do return
//     mu.end_treenode(&_engine.ui.ctx)
// }

// @(private="file")
// ui_rect_with_offset :: proc(rect: Rect, offset: Vector2i32) -> Rect {
//     return { rect.x + offset.x, rect.y + offset.y, rect.w, rect.h }
// }

// @(private="file")
// _ui_render_atlas_texture :: proc(source: mu.Rect, destination: ^mu.Rect, color: mu.Color) {
//     scale := _engine.renderer.rendering_scale

//     destination.w = source.w
//     destination.h = source.h

//     _engine.renderer.rendering_scale = 1
//     renderer_draw_texture_no_offset(
//         _engine.ui.atlas_texture,
//         &{ source.x, source.y, source.w, source.h },
//         &{ f32(destination.x), f32(destination.y), f32(destination.w), f32(destination.h) },
//         Color(color),
//     )
//     _engine.renderer.rendering_scale = scale
// }
