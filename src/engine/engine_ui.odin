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

UI_Style            :: imgui.Style
UI_Color            :: imgui.Col
UI_Vec2             :: imgui.Vec2
UI_Vec4             :: imgui.Vec4
UI_Tree_Node_Flags  :: imgui.TreeNodeFlags
UI_Window_Flag      :: imgui.WindowFlag
UI_Table_Flags      :: imgui.TableFlags
UI_Color_Edit_Flags :: imgui.ColorEditFlags
UI_StyleVar         :: imgui.StyleVar
UI_Cond             :: imgui.Cond

ui_begin :: proc(name: string, p_open: ^bool, flags: UI_Window_Flag = .None) -> bool {
    return imgui.Begin(strings.clone_to_cstring(name, context.temp_allocator), p_open, flags)
}
ui_end :: proc() {
    when IMGUI_ENABLE == false { return }
    imgui.End()
}
ui_begin_child_str :: proc(str_id: cstring, size: UI_Vec2, border: bool, flags: UI_Window_Flag) -> bool {
    when IMGUI_ENABLE == false { return false }
    return imgui.BeginChild(str_id, size, border, flags)
}
ui_begin_main_menu_bar :: proc() -> bool {
    when IMGUI_ENABLE == false { return false }
    return imgui.BeginMainMenuBar()
}
ui_begin_menu :: proc(label: cstring, enabled: bool) -> bool {
    when IMGUI_ENABLE == false { return false }
    return imgui.BeginMenuEx(label, enabled)
}
ui_begin_table :: proc(str_id: cstring, column: c.int, flags: UI_Table_Flags) -> bool {
    when IMGUI_ENABLE == false { return false }
    return imgui.BeginTable(str_id, column, flags)
}
ui_button :: proc(label: cstring) -> bool {
    when IMGUI_ENABLE == false { return false }
    return imgui.Button(label)
}
ui_checkbox :: proc(label: cstring, v: ^bool) -> bool {
    when IMGUI_ENABLE == false { return false }
    return imgui.Checkbox(label, v)
}
ui_color_edit4 :: proc(label: cstring, col: ^[4]f32, flags: UI_Color_Edit_Flags) -> bool {
    when IMGUI_ENABLE == false { return false }
    return imgui.ColorEdit4(label, col, flags)
}
ui_end_child :: proc() {
    when IMGUI_ENABLE == false { return }
    imgui.EndChild()
}
ui_end_main_menu_bar :: proc() {
    when IMGUI_ENABLE == false { return }
    imgui.EndMainMenuBar()
}
ui_end_menu :: proc() {
    when IMGUI_ENABLE == false { return }
    imgui.EndMenu()
}
ui_get_style_color_vec4 :: proc(idx: UI_Color) -> ^UI_Vec4 {
    when IMGUI_ENABLE == false { return nil }
    return imgui.GetStyleColorVec4(idx)
}
ui_menu_item_bool_ptr :: proc(label: string, shortcut: string, p_selected: ^bool, enabled: bool) -> bool {
    when IMGUI_ENABLE == false { return false }
    return imgui.MenuItemBoolPtr(strings.clone_to_cstring(label, context.temp_allocator), strings.clone_to_cstring(shortcut, context.temp_allocator), p_selected, enabled)
}
ui_push_style_color :: proc(idx: UI_Color, col: UI_Vec4) {
    when IMGUI_ENABLE == false { return }
    imgui.PushStyleColorImVec4(idx, col)
}
ui_tree_node_ex :: proc(label: cstring, flags: UI_Tree_Node_Flags) -> bool {
    when IMGUI_ENABLE == false { return false }
    return imgui.TreeNodeEx(label, flags)
}
ui_plot_lines_ex :: proc(label: cstring, values: ^f32, values_count: c.int, values_offset: c.int, overlay_text: cstring, scale_min: f32, scale_max: f32, graph_size: UI_Vec2, stride: c.int) {
    when IMGUI_ENABLE == false { return }
    imgui.PlotLinesEx(label, values, values_count, values_offset, overlay_text, scale_min, scale_max, graph_size, stride)
}
ui_pop_style_color :: proc(count: c.int) {
    when IMGUI_ENABLE == false { return }
    imgui.PopStyleColorEx(count)
}
ui_pop_style_var :: proc(count: c.int) {
    when IMGUI_ENABLE == false { return }
    imgui.PopStyleVarEx(count)
}
ui_push_style_var_float :: proc(idx: UI_StyleVar, val: f32) {
    when IMGUI_ENABLE == false { return }
    imgui.PushStyleVar(idx, val)
}
ui_push_style_var_vec2 :: proc(idx: UI_StyleVar, val: UI_Vec2) {
    when IMGUI_ENABLE == false { return }
    imgui.PushStyleVarImVec2(idx, val)
}
ui_set_window_pos_vec2 :: proc(pos: UI_Vec2, cond: UI_Cond) {
    when IMGUI_ENABLE == false { return }
    imgui.SetWindowPos(pos, cond)
}
ui_set_window_size_vec2 :: proc(size: UI_Vec2, cond: UI_Cond) {
    when IMGUI_ENABLE == false { return }
    imgui.SetWindowSize(size, cond)
}
ui_show_demo_window :: proc(p_open: ^bool) {
    when IMGUI_ENABLE == false { return }
    imgui.ShowDemoWindow(p_open)
}
ui_text :: proc(v: string, args: ..any) {
    when IMGUI_ENABLE == false { return }
    imgui.Text(strings.clone_to_cstring(fmt.tprintf(v, ..args), context.temp_allocator))
}
ui_tree_pop :: proc() {
    when IMGUI_ENABLE == false { return }
    imgui.TreePop()
}
ui_menu_item_ex :: proc(label: cstring, shortcut: cstring, selected: bool, enabled: bool) -> bool {
    when IMGUI_ENABLE == false { return false }
    return imgui.MenuItemEx(label, shortcut, selected, enabled)
}
ui_progress_bar :: proc(fraction: f32, size_arg: UI_Vec2, overlay: cstring) {
    when IMGUI_ENABLE == false { return }
    imgui.ProgressBar(fraction, size_arg, overlay)
}

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
ui_menu :: proc(label: cstring, enabled := bool(true)) -> bool {
    when IMGUI_ENABLE == false { return false }
    return ui_begin_menu(label, enabled)
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
ui_tree_node :: proc(label: cstring, flags : UI_Tree_Node_Flags = {}) -> bool {
    when IMGUI_ENABLE == false { return false }
    return ui_tree_node_ex(label, flags)
}
_ui_end_tree_node :: proc(open: bool) {
    when IMGUI_ENABLE == false { return }
    if open {
        ui_tree_pop()
    }
}

@(deferred_none=_ui_end)
ui_window :: proc(name: string, p_open : ^bool = nil, flags: UI_Window_Flag = .None) -> bool {
    when IMGUI_ENABLE == false { return false }
    return ui_begin(name, p_open, flags)
}
_ui_end :: proc() {
    when IMGUI_ENABLE == false { return }
    ui_end()
}

@(deferred_out=_ui_child_end)
ui_child :: proc(name: cstring, size: UI_Vec2, border := false, flags: UI_Window_Flag = .None) -> bool {
    when IMGUI_ENABLE == false { return false }
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
        color := ui_get_style_color_vec4(UI_Color.Button)
        ui_push_style_color(UI_Color.Button, { 0.5, 0.5, 0.5, color.w })
        ui_push_style_color(UI_Color.ButtonHovered, { 0.5, 0.5, 0.5, color.w })
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
    _r.debug_notification.start = time.now()
    _r.debug_notification.duration = duration
    _r.debug_notification.text = text
}

ui_debug_window_notification :: proc() {
    when IMGUI_ENABLE == false { return }

    if _r.debug_notification.start._nsec > 0 {
        if time.since(_r.debug_notification.start) > _r.debug_notification.duration {
            _r.debug_notification = { }
        } else {
            if ui_window("Notification", nil, .NoResize | .NoMove) {
                ui_set_window_pos_vec2({ _r.rendering_size.x / _r.pixel_density - 200, _r.rendering_size.y / _r.pixel_density - 100 }, .Always)
                ui_text(_r.debug_notification.text)
            }
        }
    }
}
