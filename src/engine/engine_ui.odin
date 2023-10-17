package engine

import "core:fmt"
import "core:time"
import "core:c"
import "core:strings"
import imgui "../odin-imgui"

Statistic_Plot :: struct {
    values: [200]f32,
    i:      int,
    stat:   Statistic,
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

ui_statistic_plots :: proc (plot: ^Statistic_Plot, value: f32, label: string, format := "%6.0f") {
    when IMGUI_ENABLE == false { }

    plot.values[plot.i] = value
    plot.i += 1
    if plot.i > len(plot.values) - 1 {
        plot.i = 0
    }
    statistic_begin(&plot.stat)
    for plot_value in plot.values {
        if plot_value == 0 {
            continue
        }
        statistic_accumulate(&plot.stat, f64(plot_value))
    }
    statistic_end(&plot.stat)

    overlay := fmt.tprintf("%s %s | min %s| max %s | avg %s", label, format, format, format, format)
    overlay = fmt.tprintf(overlay, value, plot.stat.min, plot.stat.max, plot.stat.average)
    ui_plot_lines_ex("", &plot.values[0], len(plot.values), 0, strings.clone_to_cstring(overlay, context.temp_allocator), f32(plot.stat.min), f32(plot.stat.max), { 0, 80 }, 0)
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

@(deferred_none=_ui_set_viewport_end)
ui_set_viewport :: proc() {
    renderer_bind_frame_buffer(&_e.renderer.frame_buffer)
    size := imgui.GetContentRegionAvail()
    renderer_rescale_frame_buffer(i32(size.x), i32(size.y), _e.renderer.render_buffer, _e.renderer.buffer_texture_id)
    renderer_set_viewport(0, 0, i32(size.x), i32(size.y))
}

@(private="file")
_ui_set_viewport_end :: proc() {
    renderer_unbind_frame_buffer()
}

@(deferred_out=_ui_child_end)
ui_child :: proc(name: cstring, size: Vec2, border := false, flags: WindowFlag = .None) -> bool {
    return ui_begin_child_str(name, size, border, flags)
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
    return ui_button(strings.clone_to_cstring(label, context.temp_allocator))
}
_ui_button_disabled_end :: proc(label: string, disabled: bool) {
    when IMGUI_ENABLE == false { return }
    if disabled {
        ui_pop_style_color(2)
    }
}

ui_create_notification :: proc(text: string, duration: time.Duration = time.Second) {
    _e.renderer.debug_notification.start = time.now()
    _e.renderer.debug_notification.duration = duration
    _e.renderer.debug_notification.text = text
}

ui_debug_window_notification :: proc() {
    when IMGUI_ENABLE == false { return }

    if _e.renderer.debug_notification.start._nsec > 0 {
        if time.since(_e.renderer.debug_notification.start) > _e.renderer.debug_notification.duration {
            _e.renderer.debug_notification = { }
        } else {
            if ui_window("Notification", nil, .NoResize | .NoMove) {
                ui_set_window_pos_vec2({ f32(_e.platform.window_size.x) / _e.renderer.pixel_density - 200, f32(_e.platform.window_size.y) / _e.renderer.pixel_density - 100 }, .Always)
                ui_text(_e.renderer.debug_notification.text)
            }
        }
    }
}

ui_draw_game_view :: proc() {
    _e.renderer.game_view_resized =  false
    size := ui_get_content_region_avail()

    if ui_game_view_resized() {
        renderer_update_viewport()
        _e.renderer.game_view_size = auto_cast(size)
        _e.renderer.game_view_resized =  true
    }

    ui_set_viewport()
    ui_image(
        rawptr(uintptr(_e.renderer.buffer_texture_id)),
        size,
        { 0, 1 }, { 1, 0 },
        { 1, 1, 1, 1 }, {},
    )
    _e.renderer.game_view_position = auto_cast(ui_get_window_pos())
}
ui_game_view_resized :: proc() -> bool {
    size := ui_get_content_region_avail()
    if size.x == 0 || size.y == 0 {
        return false
    }
    return size.x != _e.renderer.game_view_size.x || size.y != _e.renderer.game_view_size.y
}

ui_init_layout :: proc() {
    dockspace_id := ui_get_id("Hello")
    // imgui.DockBuilderRemoveNode(dockspace_id)
    // imgui.DockBuilderAddNode(dockspace_id, ImGuiDockNodeFlags_Dockspace)
    // imgui.DockBuilderSetNodeSize(dockspace_id, dockspace_size)

    // ImGuiID dock_main_id = dockspace_id; // This variable will track the document node, however we are not using it here as we aren't docking anything into it.
    // ImGuiID dock_id_prop = imgui.DockBuilderSplitNode(dock_main_id, ImGuiDir_Left, 0.20f, NULL, &dock_main_id);
    // ImGuiID dock_id_bottom = imgui.DockBuilderSplitNode(dock_main_id, ImGuiDir_Down, 0.20f, NULL, &dock_main_id);

    // imgui.DockBuilderDockWindow("Log", dock_id_bottom);
    // imgui.DockBuilderDockWindow("Properties", dock_id_prop);
    // imgui.DockBuilderDockWindow("Mesh", dock_id_prop);
    // imgui.DockBuilderDockWindow("Extra", dock_id_prop);
    // imgui.DockBuilderFinish(dockspace_id);
}

ui_get_id                           :: proc(str_id: cstring) -> imgui.ID { when !IMGUI_ENABLE { return 0 } return imgui.GetID(str_id) }
ui_dock_space                       :: proc(id: imgui.ID, size: imgui.Vec2, flags: imgui.DockNodeFlags, window_class: ^imgui.WindowClass = nil) -> imgui.ID { when !IMGUI_ENABLE { return 0 } return imgui.DockSpaceEx(id, size, flags, window_class) }
ui_dock_space_over_viewport         :: proc() -> imgui.ID { when !IMGUI_ENABLE { return 0 } return imgui.DockSpaceOverViewport() }
ui_dock_space_over_viewport_ex      :: proc(viewport: ^imgui.Viewport, flags: imgui.DockNodeFlags, window_class: ^imgui.WindowClass) -> imgui.ID { when !IMGUI_ENABLE { return 0 } return imgui.DockSpaceOverViewportEx(viewport, flags, window_class) }

ui_collapsing_header                :: proc(label: cstring, flags: imgui.TreeNodeFlags) -> bool { when !IMGUI_ENABLE { return false } return imgui.CollapsingHeader(label, flags) }
ui_menu_item                        :: proc(label: cstring) -> bool { when !IMGUI_ENABLE { return false } return imgui.MenuItem(label) }
@(disabled=!IMGUI_ENABLE) ui_push_id                          :: proc(int_id: c.int) { imgui.PushIDInt(int_id) }
@(disabled=!IMGUI_ENABLE) ui_push_style_color                 :: proc(idx: imgui.Col, col: imgui.Vec4) { imgui.PushStyleColorImVec4(idx, col) }
ui_tree_node_ex                     :: proc(label: cstring, flags: imgui.TreeNodeFlags) -> bool { when !IMGUI_ENABLE { return false } return imgui.TreeNodeEx(label, flags) }
@(disabled=!IMGUI_ENABLE) ui_draw_list_add_rect_filled        :: proc(self: ^imgui.DrawList, p_min: imgui.Vec2, p_max: imgui.Vec2, col: u32) { imgui.DrawList_AddRectFilled(self, p_min, p_max, col) }
ui_begin                            :: proc(name: string, p_open: ^bool, flags: WindowFlag = .None) -> bool { when !IMGUI_ENABLE { return false } return imgui.Begin(strings.clone_to_cstring(name, context.temp_allocator), p_open, flags) }
ui_begin_child_str                  :: proc(str_id: cstring, size: imgui.Vec2, border: bool, flags: imgui.WindowFlag) -> bool { when !IMGUI_ENABLE { return false } return imgui.BeginChild(str_id, size, border, flags) }
ui_begin_main_menu_bar              :: proc() -> bool { when !IMGUI_ENABLE { return false } return imgui.BeginMainMenuBar() }
ui_begin_menu                       :: proc(label: cstring, enabled: bool) -> bool { when !IMGUI_ENABLE { return false } return imgui.BeginMenuEx(label, enabled) }
ui_begin_table                      :: proc(str_id: cstring, column: c.int, flags: imgui.TableFlags = {}) -> bool { when !IMGUI_ENABLE { return false } return imgui.BeginTable(str_id, column, flags) }
ui_button                           :: proc(label: cstring) -> bool { when !IMGUI_ENABLE { return false } return imgui.Button(label) }
ui_checkbox                         :: proc(label: cstring, v: ^bool) -> bool { when !IMGUI_ENABLE { return false } return imgui.Checkbox(label, v) }
ui_color_edit4                      :: proc(label: cstring, col: ^[4]f32, flags: imgui.ColorEditFlags) -> bool { when !IMGUI_ENABLE { return false } return imgui.ColorEdit4(label, col, flags) }
@(disabled=!IMGUI_ENABLE) ui_dummy                            :: proc(size: imgui.Vec2) { imgui.Dummy(size) }
@(disabled=!IMGUI_ENABLE) ui_end                              :: proc() { imgui.End() }
@(disabled=!IMGUI_ENABLE) ui_end_child                        :: proc() { imgui.EndChild() }
@(disabled=!IMGUI_ENABLE) ui_end_main_menu_bar                :: proc() { imgui.EndMainMenuBar() }
@(disabled=!IMGUI_ENABLE) ui_end_menu                         :: proc() { imgui.EndMenu() }
@(disabled=!IMGUI_ENABLE) ui_end_table                        :: proc() { imgui.EndTable() }
ui_get_foreground_draw_list :: proc() -> ^imgui.DrawList { when !IMGUI_ENABLE { return nil } return imgui.GetForegroundDrawList() }
ui_get_color_u32_vec4               :: proc(col: Vec4) -> u32 { when !IMGUI_ENABLE { return 0 } return imgui.GetColorU32ImVec4(col) }
ui_get_content_region_avail         :: proc() -> imgui.Vec2 { return imgui.GetContentRegionAvail() }
ui_get_item_rect_min                :: proc() -> imgui.Vec2 { return imgui.GetItemRectMin() }
ui_get_style_color_vec4             :: proc(idx: imgui.Col) -> ^imgui.Vec4 { return imgui.GetStyleColorVec4(idx) }
ui_get_window_pos                   :: proc() -> imgui.Vec2 { when !IMGUI_ENABLE { return {} } return imgui.GetWindowPos() }
ui_get_window_size                  :: proc() -> imgui.Vec2 { return imgui.GetWindowSize() }
@(disabled=!IMGUI_ENABLE) ui_image                            :: proc(user_texture_id: imgui.TextureID, size: imgui.Vec2, uv0: imgui.Vec2, uv1: imgui.Vec2, tint_col: imgui.Vec4, border_col: imgui.Vec4) { imgui.ImageEx(user_texture_id, size, uv0, uv1, tint_col, border_col) }
ui_input_float                      :: proc(label: cstring, v: ^f32) -> bool { return imgui.InputFloat(label, v) }
ui_input_float2                     :: proc(label: cstring, v: ^[2]f32) -> bool { return imgui.InputFloat2(label, v) }
ui_input_float3                     :: proc(label: cstring, v: ^[3]f32) -> bool { return imgui.InputFloat3(label, v) }
ui_input_float4                     :: proc(label: cstring, v: ^[4]f32) -> bool { return imgui.InputFloat4(label, v) }
ui_input_int                        :: proc(label: cstring, v: ^c.int) -> bool { when !IMGUI_ENABLE { return false } return imgui.InputInt(label, v) }
ui_input_int2                       :: proc(label: cstring, v: ^[2]c.int, flags: imgui.InputTextFlags = {}) -> bool { when !IMGUI_ENABLE { return false } return imgui.InputInt2(label, v, flags) }
ui_input_int3                       :: proc(label: cstring, v: ^[3]c.int, flags: imgui.InputTextFlags = {}) -> bool { when !IMGUI_ENABLE { return false } return imgui.InputInt3(label, v, flags) }
ui_input_int4                       :: proc(label: cstring, v: ^[4]c.int, flags: imgui.InputTextFlags = {}) -> bool { when !IMGUI_ENABLE { return false } return imgui.InputInt4(label, v, flags) }
ui_is_mouse_clicked                 :: proc(button: imgui.MouseButton) -> bool { when !IMGUI_ENABLE { return false } return imgui.IsMouseClicked(button) }
ui_is_mouse_hovering_rect           :: proc(r_min: imgui.Vec2, r_max: imgui.Vec2) -> bool { when !IMGUI_ENABLE { return false } return imgui.IsMouseHoveringRect(r_min, r_max) }
ui_menu_item_ex                     :: proc(label: cstring, shortcut: cstring, selected: bool, enabled: bool) -> bool { when !IMGUI_ENABLE { return false } return imgui.MenuItemEx(label, shortcut, selected, enabled) }
ui_menu_item_bool_ptr               :: proc(label: string, shortcut: string, p_selected: ^bool, enabled: bool) -> bool { when !IMGUI_ENABLE { return false } return imgui.MenuItemBoolPtr(strings.clone_to_cstring(label, context.temp_allocator), strings.clone_to_cstring(shortcut, context.temp_allocator), p_selected, enabled) }
@(disabled=!IMGUI_ENABLE) ui_plot_lines_ex                    :: proc(label: cstring, values: ^f32, values_count: c.int, values_offset: c.int, overlay_text: cstring, scale_min: f32, scale_max: f32, graph_size: imgui.Vec2, stride: c.int) { imgui.PlotLinesEx(label, values, values_count, values_offset, overlay_text, scale_min, scale_max, graph_size, stride) }
@(disabled=!IMGUI_ENABLE) ui_plot_lines_fn_float_ptr          :: proc(label: cstring, values_getter: proc "c" (data: rawptr,idx: c.int) -> f32, data: rawptr, values_count: c.int, values_offset: c.int, overlay_text: cstring, scale_min: f32, scale_max: f32, graph_size: imgui.Vec2) { imgui.PlotLinesCallbackEx(label, values_getter, data, values_count, values_offset, overlay_text, scale_min, scale_max, graph_size) }
@(disabled=!IMGUI_ENABLE) ui_pop_id                           :: proc() { imgui.PopID() }
@(disabled=!IMGUI_ENABLE) ui_pop_item_width                   :: proc() { imgui.PopItemWidth() }
@(disabled=!IMGUI_ENABLE) ui_pop_style_color                  :: proc(count: c.int) { imgui.PopStyleColorEx(count) }
@(disabled=!IMGUI_ENABLE) ui_pop_style_var                    :: proc(count: c.int) { imgui.PopStyleVarEx(count) }
@(disabled=!IMGUI_ENABLE) ui_progress_bar                     :: proc(fraction: f32, size_arg: imgui.Vec2, overlay: string) { imgui.ProgressBar(fraction, size_arg, strings.clone_to_cstring(overlay, context.temp_allocator)) }
@(disabled=!IMGUI_ENABLE) ui_push_item_width                  :: proc(item_width: f32) { imgui.PushItemWidth(item_width) }
@(disabled=!IMGUI_ENABLE) ui_push_style_var_float             :: proc(idx: imgui.StyleVar, val: f32) { imgui.PushStyleVar(idx, val) }
@(disabled=!IMGUI_ENABLE) ui_push_style_var_vec2              :: proc(idx: imgui.StyleVar, val: imgui.Vec2) { imgui.PushStyleVarImVec2(idx, val) }
@(disabled=!IMGUI_ENABLE) ui_same_line                        :: proc() { imgui.SameLine() }
@(disabled=!IMGUI_ENABLE) ui_same_line_ex                     :: proc(offset_from_start_x: f32, spacing: f32) { imgui.SameLineEx(offset_from_start_x, spacing) }
@(disabled=!IMGUI_ENABLE) ui_set_window_pos_vec2              :: proc(pos: imgui.Vec2, cond: imgui.Cond) { imgui.SetWindowPos(pos, cond) }
@(disabled=!IMGUI_ENABLE) ui_set_window_size_vec2             :: proc(size: imgui.Vec2, cond: imgui.Cond) { imgui.SetWindowSize(size, cond) }
@(disabled=!IMGUI_ENABLE) ui_show_demo_window                 :: proc(p_open: ^bool) { imgui.ShowDemoWindow(p_open) }
ui_slider_float                     :: proc(label: cstring, v: ^f32, v_min: f32, v_max: f32) -> bool { when !IMGUI_ENABLE { return false } return imgui.SliderFloat(label, v, v_min, v_max) }
ui_slider_float2                    :: proc(label: cstring, v: ^[2]f32, v_min: f32, v_max: f32) -> bool { when !IMGUI_ENABLE { return false } return imgui.SliderFloat2(label, v, v_min, v_max) }
ui_slider_float3                    :: proc(label: cstring, v: ^[3]f32, v_min: f32, v_max: f32) -> bool { when !IMGUI_ENABLE { return false } return imgui.SliderFloat3(label, v, v_min, v_max) }
ui_slider_float4                    :: proc(label: cstring, v: ^[4]f32, v_min: f32, v_max: f32) -> bool { when !IMGUI_ENABLE { return false } return imgui.SliderFloat4(label, v, v_min, v_max) }
ui_slider_float_ex                  :: proc(label: cstring, v: ^f32, v_min: f32, v_max: f32, format: cstring, flags: imgui.SliderFlags) -> bool { when !IMGUI_ENABLE { return false } return imgui.SliderFloatEx(label, v, v_min, v_max, format, flags) }
ui_slider_float2_ex                 :: proc(label: cstring, v: ^[2]f32, v_min: f32, v_max: f32, format: cstring, flags: imgui.SliderFlags) -> bool { when !IMGUI_ENABLE { return false } return imgui.SliderFloat2Ex(label, v, v_min, v_max, format, flags) }
ui_slider_float3_ex                 :: proc(label: cstring, v: ^[3]f32, v_min: f32, v_max: f32, format: cstring, flags: imgui.SliderFlags) -> bool { when !IMGUI_ENABLE { return false } return imgui.SliderFloat3Ex(label, v, v_min, v_max, format, flags) }
ui_slider_float4_ex                 :: proc(label: cstring, v: ^[4]f32, v_min: f32, v_max: f32, format: cstring, flags: imgui.SliderFlags) -> bool { when !IMGUI_ENABLE { return false } return imgui.SliderFloat4Ex(label, v, v_min, v_max, format, flags) }
ui_slider_int                       :: proc(label: cstring, v: ^c.int, v_min: c.int, v_max: c.int) -> bool { when !IMGUI_ENABLE { return false } return imgui.SliderInt(label, v, v_min, v_max) }
ui_slider_int2                      :: proc(label: cstring, v: ^[2]c.int, v_min: c.int, v_max: c.int) -> bool { when !IMGUI_ENABLE { return false } return imgui.SliderInt2(label, v, v_min, v_max) }
ui_slider_int3                      :: proc(label: cstring, v: ^[3]c.int, v_min: c.int, v_max: c.int) -> bool { when !IMGUI_ENABLE { return false } return imgui.SliderInt3(label, v, v_min, v_max) }
ui_slider_int4                      :: proc(label: cstring, v: ^[4]c.int, v_min: c.int, v_max: c.int) -> bool { when !IMGUI_ENABLE { return false } return imgui.SliderInt4(label, v, v_min, v_max) }
@(disabled=!IMGUI_ENABLE) ui_table_next_row                   :: proc() { imgui.TableNextRow() }
ui_table_set_column_index           :: proc(column_n: c.int) -> bool { when !IMGUI_ENABLE { return false } return imgui.TableSetColumnIndex(column_n) }
@(disabled=!IMGUI_ENABLE) ui_text                             :: proc(v: string, args: ..any) { imgui.Text(strings.clone_to_cstring(fmt.tprintf(v, ..args), context.temp_allocator)) }
@(disabled=!IMGUI_ENABLE) ui_tree_pop                         :: proc() { imgui.TreePop() }
ui_get_cursor_screen_pos            :: proc() -> Vec2 { when !IMGUI_ENABLE { return {} } return imgui.GetCursorScreenPos() }
