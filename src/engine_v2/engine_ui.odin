package engine_v2

import "core:c"
import "core:time"
import "core:log"
import "core:fmt"
import "core:strings"
import "core:mem/virtual"
import imgui "../odin-imgui"
import "../odin-imgui/imgui_impl_sdl2"
import "../odin-imgui/imgui_impl_opengl3"
import "../statistic"
import "../tools"

ui_init :: proc(window, gl_context: rawptr, loc := #caller_location) {
    imgui.CHECKVERSION()
    imgui.CreateContext(nil)
    io := imgui.GetIO()
    io.ConfigFlags += { .NavEnableKeyboard, .NavEnableGamepad }
    when imgui.IMGUI_BRANCH == "docking" {
        io.ConfigFlags += { .DockingEnable /*, .ViewportsEnable */ }
    }

    imgui_impl_sdl2.InitForOpenGL(auto_cast(window), gl_context)
    imgui_impl_opengl3.Init(nil)
}

ui_process_event :: proc(e: ^Event) {
    imgui_impl_sdl2.ProcessEvent(e)
}

@(private) ui_quit :: proc() {
    imgui_impl_opengl3.Shutdown()
    imgui_impl_sdl2.Shutdown()
    imgui.DestroyContext(nil)
}

@(private) ui_frame_begin :: proc() {
    imgui_impl_opengl3.NewFrame()
    imgui_impl_sdl2.NewFrame()
    imgui.NewFrame()
}

@(private) ui_frame_end :: proc() {
    imgui.Render()
    imgui_impl_opengl3.RenderDrawData(imgui.GetDrawData())
}

Statistic_Plot :: struct {
    values: [200]f32,
    i:      int,
    stat:   statistic.Statistic,
}

UI_Notification :: struct {
    start:    time.Time,
    duration: time.Duration,
    text:     string,
}

Col :: imgui.Col
Vec2 :: imgui.Vec2
Vec4 :: imgui.Vec4
WindowFlag :: imgui.WindowFlag
TableFlags_None :: imgui.TableFlags_None
TableFlags_Resizable :: imgui.TableFlags_Resizable
TableFlags_Reorderable :: imgui.TableFlags_Reorderable
TableFlags_Hideable :: imgui.TableFlags_Hideable
TableFlags_Sortable :: imgui.TableFlags_Sortable
TableFlags_NoSavedSettings :: imgui.TableFlags_NoSavedSettings
TableFlags_ContextMenuInBody :: imgui.TableFlags_ContextMenuInBody
TableFlags_RowBg :: imgui.TableFlags_RowBg
TableFlags_BordersInnerH :: imgui.TableFlags_BordersInnerH
TableFlags_BordersOuterH :: imgui.TableFlags_BordersOuterH
TableFlags_BordersInnerV :: imgui.TableFlags_BordersInnerV
TableFlags_BordersOuterV :: imgui.TableFlags_BordersOuterV
TableFlags_BordersH :: imgui.TableFlags_BordersH
TableFlags_BordersV :: imgui.TableFlags_BordersV
TableFlags_BordersInner :: imgui.TableFlags_BordersInner
TableFlags_BordersOuter :: imgui.TableFlags_BordersOuter
TableFlags_Borders :: imgui.TableFlags_Borders
TableFlags_NoBordersInBody :: imgui.TableFlags_NoBordersInBody
TableFlags_NoBordersInBodyUntilResize :: imgui.TableFlags_NoBordersInBodyUntilResize
TableFlags_SizingFixedFit :: imgui.TableFlags_SizingFixedFit
TableFlags_SizingFixedSame :: imgui.TableFlags_SizingFixedSame
TableFlags_SizingStretchProp :: imgui.TableFlags_SizingStretchProp
TableFlags_SizingStretchSame :: imgui.TableFlags_SizingStretchSame
TableFlags_NoHostExtendX :: imgui.TableFlags_NoHostExtendX
TableFlags_NoHostExtendY :: imgui.TableFlags_NoHostExtendY
TableFlags_NoKeepColumnsVisible :: imgui.TableFlags_NoKeepColumnsVisible
TableFlags_PreciseWidths :: imgui.TableFlags_PreciseWidths
TableFlags_NoClip :: imgui.TableFlags_NoClip
TableFlags_PadOuterX :: imgui.TableFlags_PadOuterX
TableFlags_NoPadOuterX :: imgui.TableFlags_NoPadOuterX
TableFlags_NoPadInnerX :: imgui.TableFlags_NoPadInnerX
TableFlags_ScrollX :: imgui.TableFlags_ScrollX
TableFlags_ScrollY :: imgui.TableFlags_ScrollY
TableFlags_SortMulti :: imgui.TableFlags_SortMulti
TableFlags_SortTristate :: imgui.TableFlags_SortTristate
TableFlags_SizingMask_ :: imgui.TableFlags_SizingMask_

Value_Getter_Proc :: #type proc "c" (data: rawptr, idx: i32) -> f32;
Input_Text_Callback :: #type proc "c" (data: ^imgui.InputTextCallbackData) -> int;

ui_statistic_plots :: proc (plot: ^Statistic_Plot, value: f32, label: string, format := "%4.0f", min: f32 = -999999, max: f32 = 999999) {
    when IMGUI_ENABLE == false { return }

    plot.values[plot.i] = value

    statistic.statistic_begin(&plot.stat)
    for plot_value in plot.values {
        if plot_value == 0 {
            continue
        }
        statistic.statistic_accumulate(&plot.stat, f64(plot_value))
    }
    statistic.statistic_end(&plot.stat)

    overlay := fmt.tprintf("%s %s | min %s| max %s | avg %s", label, format, format, format, format)
    overlay = fmt.tprintf(overlay, value, plot.stat.min, plot.stat.max, plot.stat.average)
    final_min := min
    if min == -999999 {
        final_min = f32(plot.stat.min)
    }
    final_max := max
    if max == 999999 {
        final_max = f32(plot.stat.max)
    }
    ui_plot_lines_ex("", &plot.values[0], len(plot.values), 0, strings.clone_to_cstring(overlay, context.temp_allocator), final_min, final_max, { 0, 80 })

    plot.i += 1
    if plot.i > len(plot.values) - 1 {
        plot.i = 0
    }
}

@(deferred_out=_ui_end_menu)
ui_menu :: proc(label: string, enabled := bool(true)) -> bool {
    when IMGUI_ENABLE == false { return false }
    return ui_begin_menu(strings.clone_to_cstring(label, context.temp_allocator), enabled)
}
_ui_end_menu :: proc(open: bool) {
    when IMGUI_ENABLE == false { return }
    if open {
        ui_end_menu()
    }
}

@(deferred_out=_ui_end_main_menu_bar)
ui_main_menu_bar :: proc() -> bool {
    when IMGUI_ENABLE == false { return false }
    return ui_begin_main_menu_bar()
}
_ui_end_main_menu_bar :: proc(open: bool) {
    when IMGUI_ENABLE == false { return }
    if open {
        ui_end_main_menu_bar()
    }
}

@(deferred_out=_ui_end_menu_bar)
ui_menu_bar :: proc() -> bool {
    when IMGUI_ENABLE == false { return false }
    return ui_begin_menu_bar()
}
_ui_end_menu_bar :: proc(open: bool) {
    when IMGUI_ENABLE == false { return }
    if open {
        ui_end_menu_bar()
    }
}

@(deferred_out=_ui_end_tree_node)
ui_tree_node :: proc(label: string, flags: imgui.TreeNodeFlags = {}) -> bool {
    when IMGUI_ENABLE == false { return false }
    return ui_tree_node_ex(strings.clone_to_cstring(label, context.temp_allocator), flags)
}
_ui_end_tree_node :: proc(open: bool) {
    when IMGUI_ENABLE == false { return }
    if open {
        ui_tree_pop()
    }
}

@(deferred_none=_ui_end)
ui_window :: proc(name: string, p_open : ^bool = nil, flags: WindowFlag = .None) -> bool {
    when IMGUI_ENABLE == false {
        return false
    }
    return ui_begin(name, p_open, flags)
}
_ui_end :: proc() {
    when IMGUI_ENABLE == false { return }
    ui_end()
}

@(deferred_out=_ui_child_end)
ui_child :: proc(name: string, size: Vec2, border := false, flags: WindowFlag = .None) -> bool {
    return ui_begin_child_str(strings.clone_to_cstring(name, context.temp_allocator), size, border, flags)
}
_ui_child_end :: proc(collapsed: bool) {
    when IMGUI_ENABLE == false { return }
    ui_end_child()
}

@(deferred_in=_ui_button_disabled_end)
ui_button_disabled :: proc(label: string, disabled: bool) -> bool {
    when IMGUI_ENABLE == false { return false }

    if disabled {
        color := ui_get_style_color_vec4(Col.Button)
        ui_push_style_color(Col.Button, { 0.5, 0.5, 0.5, color.w })
        ui_push_style_color(Col.ButtonHovered, { 0.5, 0.5, 0.5, color.w })
    }
    return ui_button(label)
}
_ui_button_disabled_end :: proc(label: string, disabled: bool) {
    when IMGUI_ENABLE == false { return }
    if disabled {
        ui_pop_style_color(2)
    }
}

ui_create_notification :: proc(text: string, duration: time.Duration = time.Second * 3) {
    log.errorf("ui_create_notification not implemented") // FIXME:
    // _renderer.debug_notification.start = time.now()
    // _renderer.debug_notification.duration = duration
    // _renderer.debug_notification.text = text
}

ui_window_notification :: proc() {
    when IMGUI_ENABLE == false { return }

    // FIXME:
    /* if _renderer.debug_notification.start._nsec > 0 {
        if time.since(_renderer.debug_notification.start) > _renderer.debug_notification.duration {
            free(&_renderer.debug_notification.text)
            _renderer.debug_notification = { }
        } else {
            if ui_window("Notification", nil, .NoResize | .NoMove) {
                size := Vector2f32 { 250, 50 }
                ui_set_window_pos_vec2({ f32(_platform.window_size.x) / _renderer.pixel_density - size.x - 50, f32(_platform.window_size.y) / _renderer.pixel_density - size.y - 50 }, .Always)
                ui_set_window_size_vec2(transmute([2]f32) size, .Always)
                ui_text(_renderer.debug_notification.text)
            }
        }
    } */
}

ui_draw_game_view :: proc() {
    fmt.panicf("ui_draw_game_view not implemented") // FIXME:
    // _renderer.game_view_resized =  false
    // size := ui_get_content_region_avail()

    // if ui_game_view_resized() {
    //     renderer_update_viewport()
    //     _renderer.game_view_size = auto_cast(size)
    //     _renderer.game_view_resized =  true
    // }

    // ui_set_viewport()
    // ui_image(
    //     rawptr(uintptr(_renderer.buffer_texture_id)),
    //     size,
    //     { 0, 1 }, { 1, 0 },
    //     { 1, 1, 1, 1 }, {},
    // )
    // _renderer.game_view_position = auto_cast(ui_get_window_pos())
}

@(deferred_out=_ui_table_end)
ui_table :: proc(columns: []string) -> bool {
    result := ui_begin_table("table", c.int(len(columns)), TableFlags_RowBg | TableFlags_SizingStretchSame | TableFlags_Resizable)
    if result {
        ui_table_next_row()
        for column, i in columns {
            ui_table_set_column_index(c.int(i))
            ui_text(column)
        }
    }
    return result
}
@(private)
_ui_table_end :: proc(open: bool) {
    if open {
        ui_end_table()
    }
}

ui_memory_arena_progress :: proc {
    ui_memory_arena_progress_data,
    ui_memory_arena_progress_virtual,
    ui_memory_arena_progress_named_virtual,
}
@(disabled=!IMGUI_ENABLE) ui_memory_arena_progress_data :: proc(name: string, offset, data_length: int) {
    label := fmt.tprintf("%v: %v", name, tools.format_arena_usage(offset, data_length))
    ui_progress_bar_label(f32(offset) / f32(data_length), label)
}
@(disabled=!IMGUI_ENABLE) ui_memory_arena_progress_virtual :: proc(name: string, virtual_arena: ^virtual.Arena) {
    ui_memory_arena_progress_data(name, int(virtual_arena.total_used), int(virtual_arena.total_reserved))
}
@(disabled=!IMGUI_ENABLE) ui_memory_arena_progress_named_virtual :: proc(named_arena: ^tools.Named_Virtual_Arena) {
    if named_arena == nil {
        ui_memory_arena_progress_data("<Nil>", 0, 0)
        return
    }
    arena := cast(^virtual.Arena) named_arena.backing_allocator.data
    ui_memory_arena_progress_virtual(named_arena.name, arena)
}

@(disabled=!IMGUI_ENABLE) ui_progress_bar_label :: proc(fraction: f32, label: string, height: f32 = 20) {
    region := ui_get_content_region_avail()
    if ui_child(fmt.tprintf("%v_left", label), { region.x * 0.25, height }, false, .NoBackground) {
        ui_progress_bar(fraction, { -1, -1 }, "")
    }
    ui_same_line()
    if ui_child(fmt.tprintf("%v_right", label), { region.x * 0.75, height }, false, .NoBackground) {
        ui_text(label)
    }
}

ui_draw_sprite_component :: proc(entity: Entity) -> bool {
    // FIXME:
    // component_sprite, component_sprite_err := entity_get_component(entity, Component_Sprite)
    // if component_sprite_err == .None {
    //     asset, asset_exists := asset_get_by_asset_id(component_sprite.texture_asset)
    //     asset_info, asset_ok := asset_get_asset_info_image(component_sprite.texture_asset)
    //     if asset_ok {
    //         texture_position, texture_size, pixel_size := texture_position_and_size(asset_info.size, component_sprite.texture_position, component_sprite.texture_size)
    //         ui_image(
    //             auto_cast(uintptr(asset_info.texture.renderer_id)),
    //             { 16, 16 },
    //             { texture_position.x, texture_position.y },
    //             { texture_position.x + texture_size.x, texture_position.y + texture_size.y },
    //             transmute(Vec4) component_sprite.tint, {},
    //         )
    //         return true
    //     }
    // }
    return false
}

ui_get_id                                               :: proc(str_id: cstring) -> imgui.ID { when !IMGUI_ENABLE { return 0 } return imgui.GetID(str_id) }
ui_dock_space                                           :: proc(id: imgui.ID, size: Vec2, flags: imgui.DockNodeFlags, window_class: ^imgui.WindowClass = nil) -> imgui.ID { when !IMGUI_ENABLE { return 0 } return imgui.DockSpaceEx(id, size, flags, window_class) }
ui_dock_space_over_viewport                             :: proc() -> imgui.ID { when !IMGUI_ENABLE { return 0 } return imgui.DockSpaceOverViewport() }
ui_dock_space_over_viewport_ex                          :: proc(viewport: ^imgui.Viewport, flags: imgui.DockNodeFlags, window_class: ^imgui.WindowClass) -> imgui.ID { when !IMGUI_ENABLE { return 0 } return imgui.DockSpaceOverViewportEx(viewport, flags, window_class) }
ui_collapsing_header                                    :: proc(label: string, flags: imgui.TreeNodeFlags = {}) -> bool { when !IMGUI_ENABLE { return false } return imgui.CollapsingHeader(strings.clone_to_cstring(label, context.temp_allocator), flags) }
ui_menu_item                                            :: proc(label: cstring) -> bool { when !IMGUI_ENABLE { return false } return imgui.MenuItem(label) }
@(disabled=!IMGUI_ENABLE) ui_push_id                    :: proc(int_id: c.int) { imgui.PushIDInt(int_id) }
@(disabled=!IMGUI_ENABLE) ui_push_style_color           :: proc(idx: imgui.Col, col: imgui.Vec4) { imgui.PushStyleColorImVec4(idx, col) }
ui_tree_node_ex                                         :: proc(label: cstring, flags: imgui.TreeNodeFlags) -> bool { when !IMGUI_ENABLE { return false } return imgui.TreeNodeEx(label, flags) }
@(disabled=!IMGUI_ENABLE) ui_draw_list_add_rect_filled  :: proc(self: ^imgui.DrawList, p_min: Vec2, p_max: Vec2, col: u32) { imgui.DrawList_AddRectFilled(self, p_min, p_max, col) }
ui_begin                                                :: proc(name: string, p_open: ^bool, flags: WindowFlag = .None) -> bool { when !IMGUI_ENABLE { return false } return imgui.Begin(strings.clone_to_cstring(name, context.temp_allocator), p_open, flags) }
ui_begin_child_str                                      :: proc(str_id: cstring, size: Vec2, border: bool, flags: imgui.WindowFlag) -> bool { when !IMGUI_ENABLE { return false } return imgui.BeginChild(str_id, size, border, flags) }
ui_begin_main_menu_bar                                  :: proc() -> bool { when !IMGUI_ENABLE { return false } return imgui.BeginMainMenuBar() }
ui_begin_menu_bar                                       :: proc() -> bool { when !IMGUI_ENABLE { return false } return imgui.BeginMenuBar() }
ui_begin_menu                                           :: proc(label: cstring, enabled: bool) -> bool { when !IMGUI_ENABLE { return false } return imgui.BeginMenuEx(label, enabled) }
ui_begin_table                                          :: proc(str_id: cstring, column: c.int, flags: imgui.TableFlags = {}) -> bool { when !IMGUI_ENABLE { return false } return imgui.BeginTable(str_id, column, flags) }
ui_button                                               :: proc(label: string) -> bool { when !IMGUI_ENABLE { return false } return imgui.Button(strings.clone_to_cstring(label, context.temp_allocator)) }
ui_checkbox                                             :: proc(label: cstring, v: ^bool) -> bool { when !IMGUI_ENABLE { return false } return imgui.Checkbox(label, v) }
ui_color_edit4                                          :: proc(label: cstring, col: ^[4]f32, flags: imgui.ColorEditFlags = {}) -> bool { when !IMGUI_ENABLE { return false } return imgui.ColorEdit4(label, col, flags) }
@(disabled=!IMGUI_ENABLE) ui_dummy                      :: proc(size: Vec2) { imgui.Dummy(size) }
@(disabled=!IMGUI_ENABLE) ui_end                        :: proc() { imgui.End() }
@(disabled=!IMGUI_ENABLE) ui_end_child                  :: proc() { imgui.EndChild() }
@(disabled=!IMGUI_ENABLE) ui_end_main_menu_bar          :: proc() { imgui.EndMainMenuBar() }
@(disabled=!IMGUI_ENABLE) ui_end_menu_bar               :: proc() { imgui.EndMenuBar() }
@(disabled=!IMGUI_ENABLE) ui_end_menu                   :: proc() { imgui.EndMenu() }
@(disabled=!IMGUI_ENABLE) ui_end_table                  :: proc() { imgui.EndTable() }
ui_get_foreground_draw_list                             :: proc() -> ^imgui.DrawList { when !IMGUI_ENABLE { return nil } return imgui.GetForegroundDrawList() }
ui_get_color_u32_vec4                                   :: proc(col: Vec4) -> u32 { when !IMGUI_ENABLE { return 0 } return imgui.GetColorU32ImVec4(col) }
ui_get_content_region_avail                             :: proc() -> Vec2 { return imgui.GetContentRegionAvail() }
ui_get_item_rect_min                                    :: proc() -> Vec2 { return imgui.GetItemRectMin() }
ui_get_style_color_vec4                                 :: proc(idx: imgui.Col) -> ^imgui.Vec4 { return imgui.GetStyleColorVec4(idx) }
ui_get_window_pos                                       :: proc() -> Vec2 { when !IMGUI_ENABLE { return {} } return imgui.GetWindowPos() }
ui_get_window_size                                      :: proc() -> Vec2 { return imgui.GetWindowSize() }
@(disabled=!IMGUI_ENABLE) ui_image                      :: proc(user_texture_id: imgui.TextureID, size: Vec2, uv0: Vec2, uv1: Vec2, tint_col: imgui.Vec4, border_col: imgui.Vec4) { imgui.ImageEx(user_texture_id, size, uv0, uv1, tint_col, border_col) }
ui_input_float                                          :: proc(label: cstring, v: ^f32) -> bool { return imgui.InputFloat(label, v) }
ui_input_float2                                         :: proc(label: cstring, v: ^[2]f32) -> bool { return imgui.InputFloat2(label, v) }
ui_input_float3                                         :: proc(label: cstring, v: ^[3]f32) -> bool { return imgui.InputFloat3(label, v) }
ui_input_float4                                         :: proc(label: cstring, v: ^[4]f32) -> bool { return imgui.InputFloat4(label, v) }
ui_input_int                                            :: proc(label: cstring, v: ^c.int) -> bool { when !IMGUI_ENABLE { return false } return imgui.InputInt(label, v) }
ui_input_int2                                           :: proc(label: cstring, v: ^[2]c.int, flags: imgui.InputTextFlags = {}) -> bool { when !IMGUI_ENABLE { return false } return imgui.InputInt2(label, v, flags) }
ui_input_int3                                           :: proc(label: cstring, v: ^[3]c.int, flags: imgui.InputTextFlags = {}) -> bool { when !IMGUI_ENABLE { return false } return imgui.InputInt3(label, v, flags) }
ui_input_int4                                           :: proc(label: cstring, v: ^[4]c.int, flags: imgui.InputTextFlags = {}) -> bool { when !IMGUI_ENABLE { return false } return imgui.InputInt4(label, v, flags) }
ui_is_mouse_clicked                                     :: proc(button: imgui.MouseButton) -> bool { when !IMGUI_ENABLE { return false } return imgui.IsMouseClicked(button) }
ui_is_mouse_hovering_rect                               :: proc(r_min: Vec2, r_max: Vec2) -> bool { when !IMGUI_ENABLE { return false } return imgui.IsMouseHoveringRect(r_min, r_max) }
ui_menu_item_ex                                         :: proc(label: cstring, shortcut: cstring, selected: bool, enabled: bool) -> bool { when !IMGUI_ENABLE { return false } return imgui.MenuItemEx(label, shortcut, selected, enabled) }
ui_menu_item_bool_ptr                                   :: proc(label: string, shortcut: string, p_selected: ^bool, enabled: bool) -> bool { when !IMGUI_ENABLE { return false } return imgui.MenuItemBoolPtr(strings.clone_to_cstring(label, context.temp_allocator), strings.clone_to_cstring(shortcut, context.temp_allocator), p_selected, enabled) }
@(disabled=!IMGUI_ENABLE) ui_plot_lines_ex              :: proc(label: string, values: ^f32, values_count: c.int, values_offset: c.int, overlay_text: cstring, scale_min: f32, scale_max: f32, graph_size: Vec2, stride: c.int = 4) { imgui.PlotLinesEx(strings.clone_to_cstring(label, context.temp_allocator), values, values_count, values_offset, overlay_text, scale_min, scale_max, graph_size, stride) }
@(disabled=!IMGUI_ENABLE) ui_plot_lines_fn_float_ptr    :: proc(label: cstring, values_getter: proc "c" (data: rawptr,idx: c.int) -> f32, data: rawptr, values_count: c.int, values_offset: c.int, overlay_text: cstring, scale_min: f32, scale_max: f32, graph_size: Vec2) { imgui.PlotLinesCallbackEx(label, values_getter, data, values_count, values_offset, overlay_text, scale_min, scale_max, graph_size) }
@(disabled=!IMGUI_ENABLE) ui_pop_id                     :: proc() { imgui.PopID() }
@(disabled=!IMGUI_ENABLE) ui_pop_item_width             :: proc() { imgui.PopItemWidth() }
@(disabled=!IMGUI_ENABLE) ui_pop_style_color            :: proc(count: c.int) { imgui.PopStyleColorEx(count) }
@(disabled=!IMGUI_ENABLE) ui_pop_style_var              :: proc(count: c.int) { imgui.PopStyleVarEx(count) }
@(disabled=!IMGUI_ENABLE) ui_progress_bar               :: proc(fraction: f32, size_arg: Vec2, overlay: string) { imgui.ProgressBar(fraction, size_arg, strings.clone_to_cstring(overlay, context.temp_allocator)) }
@(disabled=!IMGUI_ENABLE) ui_push_item_width            :: proc(item_width: f32) { imgui.PushItemWidth(item_width) }
@(disabled=!IMGUI_ENABLE) ui_push_style_var_float       :: proc(idx: imgui.StyleVar, val: f32) { imgui.PushStyleVar(idx, val) }
@(disabled=!IMGUI_ENABLE) ui_push_style_var_vec2        :: proc(idx: imgui.StyleVar, val: Vec2) { imgui.PushStyleVarImVec2(idx, val) }
@(disabled=!IMGUI_ENABLE) ui_same_line                  :: proc() { imgui.SameLine() }
@(disabled=!IMGUI_ENABLE) ui_same_line_ex               :: proc(offset_from_start_x: f32, spacing: f32) { imgui.SameLineEx(offset_from_start_x, spacing) }
@(disabled=!IMGUI_ENABLE) ui_set_window_pos_vec2        :: proc(pos: Vec2, cond: imgui.Cond = {}) { imgui.SetWindowPos(pos, cond) }
@(disabled=!IMGUI_ENABLE) ui_set_window_size_vec2       :: proc(size: Vec2, cond: imgui.Cond = {}) { imgui.SetWindowSize(size, cond) }
@(disabled=!IMGUI_ENABLE) ui_show_demo_window           :: proc(p_open: ^bool) { if p_open^ { imgui.ShowDemoWindow(p_open) } }
ui_slider_float                                         :: proc(label: string, v: ^f32, v_min: f32, v_max: f32) -> bool { when !IMGUI_ENABLE { return false } return imgui.SliderFloat(strings.clone_to_cstring(label, context.temp_allocator), v, v_min, v_max) }
ui_slider_float2                                        :: proc(label: string, v: ^[2]f32, v_min: f32, v_max: f32) -> bool { when !IMGUI_ENABLE { return false } return imgui.SliderFloat2(strings.clone_to_cstring(label, context.temp_allocator), v, v_min, v_max) }
ui_slider_float3                                        :: proc(label: string, v: ^[3]f32, v_min: f32, v_max: f32) -> bool { when !IMGUI_ENABLE { return false } return imgui.SliderFloat3(strings.clone_to_cstring(label, context.temp_allocator), v, v_min, v_max) }
ui_slider_float4                                        :: proc(label: string, v: ^[4]f32, v_min: f32, v_max: f32) -> bool { when !IMGUI_ENABLE { return false } return imgui.SliderFloat4(strings.clone_to_cstring(label, context.temp_allocator), v, v_min, v_max) }
ui_slider_float_ex                                      :: proc(label: string, v: ^f32, v_min: f32, v_max: f32, format: cstring, flags: imgui.SliderFlags) -> bool { when !IMGUI_ENABLE { return false } return imgui.SliderFloatEx(strings.clone_to_cstring(label, context.temp_allocator), v, v_min, v_max, format, flags) }
ui_slider_float2_ex                                     :: proc(label: string, v: ^[2]f32, v_min: f32, v_max: f32, format: cstring, flags: imgui.SliderFlags) -> bool { when !IMGUI_ENABLE { return false } return imgui.SliderFloat2Ex(strings.clone_to_cstring(label, context.temp_allocator), v, v_min, v_max, format, flags) }
ui_slider_float3_ex                                     :: proc(label: string, v: ^[3]f32, v_min: f32, v_max: f32, format: cstring, flags: imgui.SliderFlags) -> bool { when !IMGUI_ENABLE { return false } return imgui.SliderFloat3Ex(strings.clone_to_cstring(label, context.temp_allocator), v, v_min, v_max, format, flags) }
ui_slider_float4_ex                                     :: proc(label: string, v: ^[4]f32, v_min: f32, v_max: f32, format: cstring, flags: imgui.SliderFlags) -> bool { when !IMGUI_ENABLE { return false } return imgui.SliderFloat4Ex(strings.clone_to_cstring(label, context.temp_allocator), v, v_min, v_max, format, flags) }
ui_slider_int                                           :: proc(label: string, v: ^c.int, v_min: c.int, v_max: c.int) -> bool { when !IMGUI_ENABLE { return false } return imgui.SliderInt(strings.clone_to_cstring(label, context.temp_allocator), v, v_min, v_max) }
ui_slider_int2                                          :: proc(label: string, v: ^[2]c.int, v_min: c.int, v_max: c.int) -> bool { when !IMGUI_ENABLE { return false } return imgui.SliderInt2(strings.clone_to_cstring(label, context.temp_allocator), v, v_min, v_max) }
ui_slider_int3                                          :: proc(label: string, v: ^[3]c.int, v_min: c.int, v_max: c.int) -> bool { when !IMGUI_ENABLE { return false } return imgui.SliderInt3(strings.clone_to_cstring(label, context.temp_allocator), v, v_min, v_max) }
ui_slider_int4                                          :: proc(label: string, v: ^[4]c.int, v_min: c.int, v_max: c.int) -> bool { when !IMGUI_ENABLE { return false } return imgui.SliderInt4(strings.clone_to_cstring(label, context.temp_allocator), v, v_min, v_max) }
@(disabled=!IMGUI_ENABLE) ui_table_next_row             :: proc() { imgui.TableNextRow() }
ui_table_set_column_index                               :: proc(column_n: c.int) -> bool { when !IMGUI_ENABLE { return false } return imgui.TableSetColumnIndex(column_n) }
@(disabled=!IMGUI_ENABLE) ui_text                       :: proc(v: string, args: ..any) { imgui.Text(strings.clone_to_cstring(fmt.tprintf(v, ..args), context.temp_allocator)) }
@(disabled=!IMGUI_ENABLE) ui_tree_pop                   :: proc() { imgui.TreePop() }
ui_get_cursor_screen_pos                                :: proc() -> Vec2 { when !IMGUI_ENABLE { return {} } return imgui.GetCursorScreenPos() }
ui_get_scroll_y                                         :: proc() -> f32 { when !IMGUI_ENABLE { return 0 } return imgui.GetScrollY() }
ui_get_scroll_max_y                                     :: proc() -> f32 { when !IMGUI_ENABLE { return 0 } return imgui.GetScrollMaxY() }
@(disabled=!IMGUI_ENABLE) ui_set_scroll_here_y          :: proc(center_y_ratio: f32) { imgui.SetScrollHereY(center_y_ratio) }
ui_input_text                                           :: proc(label: string, buf: cstring, buf_size: c.size_t, flags: imgui.InputTextFlags = {}) -> bool { when !IMGUI_ENABLE { return false } return imgui.InputText(strings.clone_to_cstring(label, context.temp_allocator), buf, buf_size, flags) }
ui_is_any_window_hovered                                :: proc() -> bool { when !IMGUI_ENABLE { return false } return imgui.IsWindowHovered(imgui.HoveredFlags_AnyWindow) }
@(disabled=!IMGUI_ENABLE) ui_set_next_item_width        :: proc(value: f32) { imgui.SetNextItemWidth(value) }
