package engine

import "core:fmt"
import "core:time"
import "core:c"
import "core:strings"

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

Value_Getter_Proc :: #type proc "c" (data: rawptr, idx: i32) -> f32;
Input_Text_Callback :: #type proc "c" (data: ^InputTextCallbackData) -> int;

ui_statistic_plots :: proc (plot: ^Statistic_Plot, value: f32, label: string, format := "%6.0f") {
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
    return ui_begin_menu(label, enabled)
}
_ui_end_menu :: proc(open: bool) {
    if open {
        ui_end_menu()
    }
}

@(deferred_out=_ui_end_main_menu_bar)
ui_main_menu_bar :: proc() -> bool {
    return ui_begin_main_menu_bar()
}
_ui_end_main_menu_bar :: proc(open: bool) {
    if open {
        ui_end_main_menu_bar()
    }
}

@(deferred_out=_ui_end_tree_node)
ui_tree_node :: proc(label: cstring, flags : Tree_Node_Flags = {}) -> bool {
    return ui_tree_node_ex(label, flags)
}
_ui_end_tree_node :: proc(open: bool) {
    if open {
        ui_tree_pop()
    }
}

@(deferred_none=_ui_end)
ui_window :: proc(name: string, p_open : ^bool = nil, flags: Window_Flag = .None) -> bool {
    when IMGUI_ENABLE == false {
        return false
    }
    return ui_begin(name, p_open, flags)
}
_ui_end :: proc() {
    when IMGUI_ENABLE == false {
        return
    }
    ui_end()
}

@(deferred_out=_ui_child_end)
ui_child :: proc(name: cstring, size: UI_Vec2, border := false, flags: Window_Flag = .None) -> bool {
    return ui_begin_child_str(name, size, border, flags)
}
_ui_child_end :: proc(collapsed: bool) {
    ui_end_child()
}

@(deferred_in=_ui_disable_button_end)
ui_disable_button :: proc(enabled: bool) {
    // FIXME:
    // if enabled {
    //     color := ui_get_style_color_vec4(UI_Color.Button)
    //     ui_push_style_color_vec4(UI_Color.Button, { 0.5, 0.5, 0.5, color.w })
    // }
    // ui_push_item_flag(.Disabled, enabled)
}
_ui_disable_button_end :: proc(enabled: bool) {
    // FIXME:
    // if enabled {
    //     ui_pop_style_color(1)
    // }
    // ui_pop_item_flag()
}

ui_create_notification :: proc(text: string, duration: time.Duration = time.Second) {
    _r.debug_notification.start = time.now()
    _r.debug_notification.duration = duration
    _r.debug_notification.text = text
}

ui_debug_window_notification :: proc() {
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

when IMGUI_ENABLE {
    import imgui "../odin-imgui"

    UI_Style                            :: imgui.Style
    UI_Color                            :: imgui.Col
    UI_Vec2                             :: imgui.Vec2
    UI_Vec4                             :: imgui.Vec4
    Tree_Node_Flags                     :: imgui.TreeNodeFlags
    Window_Flag                         :: imgui.WindowFlag
    // Window_Flag                        :: imgui.WindowFlags
    InputTextCallbackData               :: imgui.InputTextCallbackData

    TableFlags :: imgui.TableFlags
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

    ui_collapsing_header                :: imgui.CollapsingHeader
    ui_get_foreground_draw_list         :: imgui.GetForegroundDrawList
    ui_menu_item                        :: imgui.MenuItem
    ui_push_id                          :: imgui.PushIDInt
    ui_push_style_color                 :: imgui.PushStyleColorImVec4
    ui_tree_node_ex                     :: imgui.TreeNodeEx
    ui_draw_list_add_rect_filled        :: imgui.DrawList_AddRectFilled
    // ui_begin                            :: imgui.Begin
    ui_begin                            :: proc(name: string, p_open: ^bool, flags: Window_Flag = .None) -> bool {
        return imgui.Begin(strings.clone_to_cstring(name, context.temp_allocator), p_open, flags)
    }
    ui_begin_child_str                  :: imgui.BeginChild
    ui_begin_main_menu_bar              :: imgui.BeginMainMenuBar
    ui_begin_menu                       :: imgui.BeginMenuEx
    ui_begin_table                      :: imgui.BeginTable
    ui_button                           :: imgui.Button
    ui_checkbox                         :: imgui.Checkbox
    ui_color_edit4                      :: imgui.ColorEdit4
    ui_dummy                            :: imgui.Dummy
    ui_end                              :: imgui.End
    ui_end_child                        :: imgui.EndChild
    ui_end_main_menu_bar                :: imgui.EndMainMenuBar
    ui_end_menu                         :: imgui.EndMenu
    ui_end_table                        :: imgui.EndTable
    ui_get_color_u32_vec4               :: imgui.GetColorU32ImVec4
    ui_get_content_region_avail         :: imgui.GetContentRegionAvail
    ui_get_item_rect_min                :: imgui.GetItemRectMin
    ui_get_style_color_vec4             :: imgui.GetStyleColorVec4
    ui_get_window_pos                   :: imgui.GetWindowPos
    ui_get_window_size                  :: imgui.GetWindowSize
    ui_image                            :: imgui.ImageEx
    ui_input_float                      :: imgui.InputFloat
    ui_input_float2                     :: imgui.InputFloat2
    ui_input_float3                     :: imgui.InputFloat3
    ui_input_float4                     :: imgui.InputFloat4
    ui_input_int                        :: imgui.InputInt
    ui_input_int2                       :: imgui.InputInt2
    ui_input_int3                       :: imgui.InputInt3
    ui_input_int4                       :: imgui.InputInt4
    ui_is_mouse_clicked                 :: imgui.IsMouseClicked
    ui_is_mouse_hovering_rect           :: imgui.IsMouseHoveringRect
    ui_menu_item_ex                     :: imgui.MenuItemEx
    // ui_menu_item_bool_ptr               :: imgui.MenuItemBoolPtr
    ui_menu_item_bool_ptr               :: proc(label: string, shortcut: string, p_selected: ^bool, enabled: bool) -> bool {
        return imgui.MenuItemBoolPtr(strings.clone_to_cstring(label, context.temp_allocator), strings.clone_to_cstring(shortcut, context.temp_allocator), p_selected, enabled)
    }
    ui_plot_lines_ex                    :: imgui.PlotLinesEx
    ui_plot_lines_fn_float_ptr          :: imgui.PlotLinesCallbackEx
    ui_pop_id                           :: imgui.PopID
    // ui_push_item_flag                   :: imgui.PushItemFlag
    // ui_pop_item_flag                    :: imgui.PopItemFlag
    ui_pop_item_width                   :: imgui.PopItemWidth
    ui_pop_style_color                  :: imgui.PopStyleColorEx
    ui_pop_style_var                    :: imgui.PopStyleVarEx
    ui_progress_bar                     :: imgui.ProgressBar
    ui_push_item_width                  :: imgui.PushItemWidth
    ui_push_style_var_float             :: imgui.PushStyleVar
    ui_push_style_var_vec2              :: imgui.PushStyleVarImVec2
    ui_same_line                        :: imgui.SameLine
    ui_same_line_ex                     :: imgui.SameLineEx
    ui_set_window_pos_vec2              :: imgui.SetWindowPos
    ui_set_window_size_vec2             :: imgui.SetWindowSize
    ui_show_demo_window                 :: imgui.ShowDemoWindow
    ui_slider_float                     :: imgui.SliderFloat
    ui_slider_float2                    :: imgui.SliderFloat2
    ui_slider_float3                    :: imgui.SliderFloat3
    ui_slider_float4                    :: imgui.SliderFloat4
    ui_slider_float_ex                  :: imgui.SliderFloatEx
    ui_slider_float2_ex                 :: imgui.SliderFloat2Ex
    ui_slider_float3_ex                 :: imgui.SliderFloat3Ex
    ui_slider_float4_ex                 :: imgui.SliderFloat4Ex
    ui_slider_int2                      :: imgui.SliderInt2
    ui_slider_int3                      :: imgui.SliderInt3
    ui_slider_int4                      :: imgui.SliderInt4
    ui_table_next_row                   :: imgui.TableNextRow
    ui_table_set_column_index           :: imgui.TableSetColumnIndex
    ui_text                             :: proc(v: string, args: ..any) {
        imgui.Text(strings.clone_to_cstring(fmt.tprintf(v, ..args), context.temp_allocator))
    }
    ui_tree_pop                         :: imgui.TreePop
} else {
    TableFlags :: distinct c.int
    // Features
    TableFlags_None              :: TableFlags(0)
    TableFlags_Resizable         :: TableFlags(1<<0) // Enable resizing columns.
    TableFlags_Reorderable       :: TableFlags(1<<1) // Enable reordering columns in header row (need calling TableSetupColumn() + TableHeadersRow() to display headers)
    TableFlags_Hideable          :: TableFlags(1<<2) // Enable hiding/disabling columns in context menu.
    TableFlags_Sortable          :: TableFlags(1<<3) // Enable sorting. Call TableGetSortSpecs() to obtain sort specs. Also see ImGuiTableFlags_SortMulti and ImGuiTableFlags_SortTristate.
    TableFlags_NoSavedSettings   :: TableFlags(1<<4) // Disable persisting columns order, width and sort settings in the .ini file.
    TableFlags_ContextMenuInBody :: TableFlags(1<<5) // Right-click on columns body/contents will display table context menu. By default it is available in TableHeadersRow().
    // Decorations
    TableFlags_RowBg                      :: TableFlags(1<<6)                                                // Set each RowBg color with ImGuiCol_TableRowBg or ImGuiCol_TableRowBgAlt (equivalent of calling TableSetBgColor with ImGuiTableBgFlags_RowBg0 on each row manually)
    TableFlags_BordersInnerH              :: TableFlags(1<<7)                                                // Draw horizontal borders between rows.
    TableFlags_BordersOuterH              :: TableFlags(1<<8)                                                // Draw horizontal borders at the top and bottom.
    TableFlags_BordersInnerV              :: TableFlags(1<<9)                                                // Draw vertical borders between columns.
    TableFlags_BordersOuterV              :: TableFlags(1<<10)                                               // Draw vertical borders on the left and right sides.
    TableFlags_BordersH                   :: TableFlags(TableFlags_BordersInnerH | TableFlags_BordersOuterH) // Draw horizontal borders.
    TableFlags_BordersV                   :: TableFlags(TableFlags_BordersInnerV | TableFlags_BordersOuterV) // Draw vertical borders.
    TableFlags_BordersInner               :: TableFlags(TableFlags_BordersInnerV | TableFlags_BordersInnerH) // Draw inner borders.
    TableFlags_BordersOuter               :: TableFlags(TableFlags_BordersOuterV | TableFlags_BordersOuterH) // Draw outer borders.
    TableFlags_Borders                    :: TableFlags(TableFlags_BordersInner | TableFlags_BordersOuter)   // Draw all borders.
    TableFlags_NoBordersInBody            :: TableFlags(1<<11)                                               // [ALPHA] Disable vertical borders in columns Body (borders will always appear in Headers). -> May move to style
    TableFlags_NoBordersInBodyUntilResize :: TableFlags(1<<12)                                               // [ALPHA] Disable vertical borders in columns Body until hovered for resize (borders will always appear in Headers). -> May move to style
    // Sizing Policy (read above for defaults)
    TableFlags_SizingFixedFit    :: TableFlags(1<<13) // Columns default to _WidthFixed or _WidthAuto (if resizable or not resizable), matching contents width.
    TableFlags_SizingFixedSame   :: TableFlags(2<<13) // Columns default to _WidthFixed or _WidthAuto (if resizable or not resizable), matching the maximum contents width of all columns. Implicitly enable ImGuiTableFlags_NoKeepColumnsVisible.
    TableFlags_SizingStretchProp :: TableFlags(3<<13) // Columns default to _WidthStretch with default weights proportional to each columns contents widths.
    TableFlags_SizingStretchSame :: TableFlags(4<<13) // Columns default to _WidthStretch with default weights all equal, unless overridden by TableSetupColumn().
    // Sizing Extra Options
    TableFlags_NoHostExtendX        :: TableFlags(1<<16) // Make outer width auto-fit to columns, overriding outer_size.x value. Only available when ScrollX/ScrollY are disabled and Stretch columns are not used.
    TableFlags_NoHostExtendY        :: TableFlags(1<<17) // Make outer height stop exactly at outer_size.y (prevent auto-extending table past the limit). Only available when ScrollX/ScrollY are disabled. Data below the limit will be clipped and not visible.
    TableFlags_NoKeepColumnsVisible :: TableFlags(1<<18) // Disable keeping column always minimally visible when ScrollX is off and table gets too small. Not recommended if columns are resizable.
    TableFlags_PreciseWidths        :: TableFlags(1<<19) // Disable distributing remainder width to stretched columns (width allocation on a 100-wide table with 3 columns: Without this flag: 33,33,34. With this flag: 33,33,33). With larger number of columns, resizing will appear to be less smooth.
    // Clipping
    TableFlags_NoClip :: TableFlags(1<<20) // Disable clipping rectangle for every individual columns (reduce draw command count, items will be able to overflow into other columns). Generally incompatible with TableSetupScrollFreeze().
    // Padding
    TableFlags_PadOuterX   :: TableFlags(1<<21) // Default if BordersOuterV is on. Enable outermost padding. Generally desirable if you have headers.
    TableFlags_NoPadOuterX :: TableFlags(1<<22) // Default if BordersOuterV is off. Disable outermost padding.
    TableFlags_NoPadInnerX :: TableFlags(1<<23) // Disable inner padding between columns (double inner padding if BordersOuterV is on, single inner padding if BordersOuterV is off).
    // Scrolling
    TableFlags_ScrollX :: TableFlags(1<<24) // Enable horizontal scrolling. Require 'outer_size' parameter of BeginTable() to specify the container size. Changes default sizing policy. Because this creates a child window, ScrollY is currently generally recommended when using ScrollX.
    TableFlags_ScrollY :: TableFlags(1<<25) // Enable vertical scrolling. Require 'outer_size' parameter of BeginTable() to specify the container size.
    // Sorting
    TableFlags_SortMulti    :: TableFlags(1<<26) // Hold shift when clicking headers to sort on multiple column. TableGetSortSpecs() may return specs where (SpecsCount > 1).
    TableFlags_SortTristate :: TableFlags(1<<27) // Allow no sorting, disable default sorting. TableGetSortSpecs() may return specs where (SpecsCount == 0).
    // [Internal] Combinations and masks
    TableFlags_SizingMask_ :: TableFlags(TableFlags_SizingFixedFit | TableFlags_SizingFixedSame | TableFlags_SizingStretchProp | TableFlags_SizingStretchSame)

    Style :: struct {
        alpha:                          f32,
        window_padding:                 Vec2,
        window_rounding:                f32,
        window_border_size:             f32,
        window_min_size:                Vec2,
        window_title_align:             Vec2,
        window_menu_button_position:    Dir,
        child_rounding:                 f32,
        child_border_size:              f32,
        popup_rounding:                 f32,
        popup_border_size:              f32,
        frame_padding:                  Vec2,
        frame_rounding:                 f32,
        frame_border_size:              f32,
        item_spacing:                   Vec2,
        item_inner_spacing:             Vec2,
        cell_padding:                   Vec2,
        touch_extra_padding:            Vec2,
        indent_spacing:                 f32,
        columns_min_spacing:            f32,
        scrollbar_size:                 f32,
        scrollbar_rounding:             f32,
        grab_min_size:                  f32,
        grab_rounding:                  f32,
        log_slider_deadzone:            f32,
        tab_rounding:                   f32,
        tab_border_size:                f32,
        tab_min_width_for_close_button: f32,
        color_button_position:          Dir,
        button_text_align:              Vec2,
        selectable_text_align:          Vec2,
        display_window_padding:         Vec2,
        display_safe_area_padding:      Vec2,
        mouse_cursor_scale:             f32,
        anti_aliased_lines:             bool,
        anti_aliased_lines_use_tex:     bool,
        anti_aliased_fill:              bool,
        curve_tessellation_tol:         f32,
        circle_tessellation_max_error:  f32,
        colors:                         [53]Vec4,
    }

    Col :: enum i32 {
        Text                  = 0,
        TextDisabled          = 1,
        WindowBg              = 2,
        ChildBg               = 3,
        PopupBg               = 4,
        Border                = 5,
        BorderShadow          = 6,
        FrameBg               = 7,
        FrameBgHovered        = 8,
        FrameBgActive         = 9,
        TitleBg               = 10,
        TitleBgActive         = 11,
        TitleBgCollapsed      = 12,
        MenuBarBg             = 13,
        ScrollbarBg           = 14,
        ScrollbarGrab         = 15,
        ScrollbarGrabHovered  = 16,
        ScrollbarGrabActive   = 17,
        CheckMark             = 18,
        SliderGrab            = 19,
        SliderGrabActive      = 20,
        Button                = 21,
        ButtonHovered         = 22,
        ButtonActive          = 23,
        Header                = 24,
        HeaderHovered         = 25,
        HeaderActive          = 26,
        Separator             = 27,
        SeparatorHovered      = 28,
        SeparatorActive       = 29,
        ResizeGrip            = 30,
        ResizeGripHovered     = 31,
        ResizeGripActive      = 32,
        Tab                   = 33,
        TabHovered            = 34,
        TabActive             = 35,
        TabUnfocused          = 36,
        TabUnfocusedActive    = 37,
        PlotLines             = 38,
        PlotLinesHovered      = 39,
        PlotHistogram         = 40,
        PlotHistogramHovered  = 41,
        TableHeaderBg         = 42,
        TableBorderStrong     = 43,
        TableBorderLight      = 44,
        TableRowBg            = 45,
        TableRowBgAlt         = 46,
        TextSelectedBg        = 47,
        DragDropTarget        = 48,
        NavHighlight          = 49,
        NavWindowingHighlight = 50,
        NavWindowingDimBg     = 51,
        ModalWindowDimBg      = 52,
        Count                 = 53,
    }

    Vec2 :: struct {
        x: f32,
        y: f32,
    }

    Vec4 :: struct {
        x: f32,
        y: f32,
        z: f32,
        w: f32,
    }

    Tree_Node_Flags :: enum i32 {
        None                 = 0,
        Selected             = 1 << 0,
        Framed               = 1 << 1,
        AllowItemOverlap     = 1 << 2,
        NoTreePushOnOpen     = 1 << 3,
        NoAutoOpenOnLog      = 1 << 4,
        DefaultOpen          = 1 << 5,
        OpenOnDoubleClick    = 1 << 6,
        OpenOnArrow          = 1 << 7,
        Leaf                 = 1 << 8,
        Bullet               = 1 << 9,
        FramePadding         = 1 << 10,
        SpanAvailWidth       = 1 << 11,
        SpanFullWidth        = 1 << 12,
        NavLeftJumpsBackHere = 1 << 13,
        CollapsingHeader     = Framed | NoTreePushOnOpen | NoAutoOpenOnLog,
    }

    Window_Flag :: bit_set[Window_Flag; c.int]
    Window_Flag :: enum c.int {
        NoTitleBar                = 0,  // Disable title-bar
        NoResize                  = 1,  // Disable user resizing with the lower-right grip
        NoMove                    = 2,  // Disable user moving the window
        NoScrollbar               = 3,  // Disable scrollbars (window can still scroll with mouse or programmatically)
        NoScrollWithMouse         = 4,  // Disable user vertically scrolling with mouse wheel. On child window, mouse wheel will be forwarded to the parent unless NoScrollbar is also set.
        NoCollapse                = 5,  // Disable user collapsing window by double-clicking on it. Also referred to as Window Menu Button (e.g. within a docking node).
        AlwaysAutoResize          = 6,  // Resize every window to its content every frame
        NoBackground              = 7,  // Disable drawing background color (WindowBg, etc.) and outside border. Similar as using SetNextWindowBgAlpha(0.0f).
        NoSavedSettings           = 8,  // Never load/save settings in .ini file
        NoMouseInputs             = 9,  // Disable catching mouse, hovering test with pass through.
        MenuBar                   = 10, // Has a menu-bar
        HorizontalScrollbar       = 11, // Allow horizontal scrollbar to appear (off by default). You may use SetNextWindowContentSize(ImVec2(width,0.0f)); prior to calling Begin() to specify width. Read code in imgui_demo in the "Horizontal Scrolling" section.
        NoFocusOnAppearing        = 12, // Disable taking focus when transitioning from hidden to visible state
        NoBringToFrontOnFocus     = 13, // Disable bringing window to front when taking focus (e.g. clicking on it or programmatically giving it focus)
        AlwaysVerticalScrollbar   = 14, // Always show vertical scrollbar (even if ContentSize.y < Size.y)
        AlwaysHorizontalScrollbar = 15, // Always show horizontal scrollbar (even if ContentSize.x < Size.x)
        AlwaysUseWindowPadding    = 16, // Ensure child windows without border uses style.WindowPadding (ignored by default for non-bordered child windows, because more convenient)
        NoNavInputs               = 18, // No gamepad/keyboard navigation within the window
        NoNavFocus                = 19, // No focusing toward this window with gamepad/keyboard navigation (e.g. skipped by CTRL+TAB)
        UnsavedDocument           = 20, // Display a dot next to the title. When used in a tab/docking context, tab is selected when clicking the X + closure is not assumed (will wait for user to stop submitting the tab). Otherwise closure is assumed when pressing the X, so if you keep submitting the tab may reappear at end of tab bar.
        NoDocking                 = 21, // Disable docking of this window
        // [Internal]
        NavFlattened = 23, // [BETA] On child window: allow gamepad/keyboard navigation to cross over parent border to this child or between sibling child windows.
        ChildWindow  = 24, // Don't use! For internal use by BeginChild()
        Tooltip      = 25, // Don't use! For internal use by BeginTooltip()
        Popup        = 26, // Don't use! For internal use by BeginPopup()
        Modal        = 27, // Don't use! For internal use by BeginPopupModal()
        ChildMenu    = 28, // Don't use! For internal use by BeginMenu()
        DockNodeHost = 29, // Don't use! For internal use by Begin()/NewFrame()
    }

    Cond :: enum i32 {
        None         = 0,
        Always       = 1 << 0,
        Once         = 1 << 1,
        FirstUseEver = 1 << 2,
        Appearing    = 1 << 3,
    }

    Table_Row_Flags :: enum i32 {
        None    = 0,
        Headers = 1 << 0,
    }

    Item_Flags :: enum i32 {
        None                     = 0,
        NoTabStop                = 1 << 0,
        ButtonRepeat             = 1 << 1,
        Disabled                 = 1 << 2,
        NoNav                    = 1 << 3,
        NoNavDefaultFocus        = 1 << 4,
        SelectableDontClosePopup = 1 << 5,
        MixedValue               = 1 << 6,
        ReadOnly                 = 1 << 7,
        Default_                 = 0
    }

    Dir :: enum i32 {
        None  = -1,
        Left  = 0,
        Right = 1,
        Up    = 2,
        Down  = 3,
        Count = 4,
    }

    Table_Flags :: enum i32 {
        None                       = 0,
        Resizable                  = 1 << 0,
        Reorderable                = 1 << 1,
        Hideable                   = 1 << 2,
        Sortable                   = 1 << 3,
        NoSavedSettings            = 1 << 4,
        ContextMenuInBody          = 1 << 5,
        RowBg                      = 1 << 6,
        BordersInnerH              = 1 << 7,
        BordersOuterH              = 1 << 8,
        BordersInnerV              = 1 << 9,
        BordersOuterV              = 1 << 10,
        BordersH                   = BordersInnerH | BordersOuterH,
        BordersV                   = BordersInnerV | BordersOuterV,
        BordersInner               = BordersInnerV | BordersInnerH,
        BordersOuter               = BordersOuterV | BordersOuterH,
        Borders                    = BordersInner | BordersOuter,
        NoBordersInBody            = 1 << 11,
        NoBordersInBodyUntilResize = 1 << 12,
        SizingFixedFit             = 1 << 13,
        SizingFixedSame            = 2 << 13,
        SizingStretchProp          = 3 << 13,
        SizingStretchSame          = 4 << 13,
        NoHostExtendX              = 1 << 16,
        NoHostExtendY              = 1 << 17,
        NoKeepColumnsVisible       = 1 << 18,
        PreciseWidths              = 1 << 19,
        NoClip                     = 1 << 20,
        PadOuterX                  = 1 << 21,
        NoPadOuterX                = 1 << 22,
        NoPadInnerX                = 1 << 23,
        ScrollX                    = 1 << 24,
        ScrollY                    = 1 << 25,
        SortMulti                  = 1 << 26,
        SortTristate               = 1 << 27,
        SizingMask                 = SizingFixedFit | SizingFixedSame | SizingStretchProp | SizingStretchSame,
    }

    Table_Bg_Target :: enum i32 {
        None   = 0,
        RowBg0 = 1,
        RowBg1 = 2,
        CellBg = 3,
    }

    Table_Column_Flags :: enum i32 {
        None                 = 0,
        DefaultHide          = 1 << 0,
        DefaultSort          = 1 << 1,
        WidthStretch         = 1 << 2,
        WidthFixed           = 1 << 3,
        NoResize             = 1 << 4,
        NoReorder            = 1 << 5,
        NoHide               = 1 << 6,
        NoClip               = 1 << 7,
        NoSort               = 1 << 8,
        NoSortAscending      = 1 << 9,
        NoSortDescending     = 1 << 10,
        NoHeaderWidth        = 1 << 11,
        PreferSortAscending  = 1 << 12,
        PreferSortDescending = 1 << 13,
        IndentEnable         = 1 << 14,
        IndentDisable        = 1 << 15,
        IsEnabled            = 1 << 20,
        IsVisible            = 1 << 21,
        IsSorted             = 1 << 22,
        IsHovered            = 1 << 23,
        WidthMask            = WidthStretch | WidthFixed,
        IndentMask           = IndentEnable | IndentDisable,
        StatusMask           = IsEnabled | IsVisible | IsSorted | IsHovered,
        NoDirectResize       = 1 << 30,
    }

    Input_Text_Flags :: enum i32 {
        None                = 0,
        CharsDecimal        = 1 << 0,
        CharsHexadecimal    = 1 << 1,
        CharsUppercase      = 1 << 2,
        CharsNoBlank        = 1 << 3,
        AutoSelectAll       = 1 << 4,
        EnterReturnsTrue    = 1 << 5,
        CallbackCompletion  = 1 << 6,
        CallbackHistory     = 1 << 7,
        CallbackAlways      = 1 << 8,
        CallbackCharFilter  = 1 << 9,
        AllowTabInput       = 1 << 10,
        CtrlEnterForNewLine = 1 << 11,
        NoHorizontalScroll  = 1 << 12,
        AlwaysOverwrite     = 1 << 13,
        ReadOnly            = 1 << 14,
        Password            = 1 << 15,
        NoUndoRedo          = 1 << 16,
        CharsScientific     = 1 << 17,
        CallbackResize      = 1 << 18,
        CallbackEdit        = 1 << 19,
        Multiline           = 1 << 20,
        NoMarkEdited        = 1 << 21,
    }

    Key :: enum i32 {
        Tab         = 0,
        LeftArrow   = 1,
        RightArrow  = 2,
        UpArrow     = 3,
        DownArrow   = 4,
        PageUp      = 5,
        PageDown    = 6,
        Home        = 7,
        End         = 8,
        Insert      = 9,
        Delete      = 10,
        Backspace   = 11,
        Space       = 12,
        Enter       = 13,
        Escape      = 14,
        KeyPadEnter = 15,
        A           = 16,
        C           = 17,
        V           = 18,
        X           = 19,
        Y           = 20,
        Z           = 21,
        Count       = 22,
    }

    InputTextCallbackData :: struct {
        event_flag:      Input_Text_Flags,
        flags:           Input_Text_Flags,
        user_data:       rawptr,
        event_char:      Wchar,
        event_key:       Key,
        buf:             cstring,
        buf_text_len:    i32,
        buf_size:        i32,
        buf_dirty:       bool,
        cursor_pos:      i32,
        selection_start: i32,
        selection_end:   i32,
    }

    Data_Type :: enum i32 {
        S8     = 0,
        U8     = 1,
        S16    = 2,
        U16    = 3,
        S32    = 4,
        U32    = 5,
        S64    = 6,
        U64    = 7,
        Float  = 8,
        Double = 9,
        Count  = 10,
    }

    Style_Var :: enum i32 {
        Alpha               = 0,
        WindowPadding       = 1,
        WindowRounding      = 2,
        WindowBorderSize    = 3,
        WindowMinSize       = 4,
        WindowTitleAlign    = 5,
        ChildRounding       = 6,
        ChildBorderSize     = 7,
        PopupRounding       = 8,
        PopupBorderSize     = 9,
        FramePadding        = 10,
        FrameRounding       = 11,
        FrameBorderSize     = 12,
        ItemSpacing         = 13,
        ItemInnerSpacing    = 14,
        IndentSpacing       = 15,
        CellPadding         = 16,
        ScrollbarSize       = 17,
        ScrollbarRounding   = 18,
        GrabMinSize         = 19,
        GrabRounding        = 20,
        TabRounding         = 21,
        ButtonTextAlign     = 22,
        SelectableTextAlign = 23,
        Count               = 24,
    }

    Color_Edit_Flags :: enum i32 {
        None             = 0,
        NoAlpha          = 1 << 1,
        NoPicker         = 1 << 2,
        NoOptions        = 1 << 3,
        NoSmallPreview   = 1 << 4,
        NoInputs         = 1 << 5,
        NoTooltip        = 1 << 6,
        NoLabel          = 1 << 7,
        NoSidePreview    = 1 << 8,
        NoDragDrop       = 1 << 9,
        NoBorder         = 1 << 10,
        AlphaBar         = 1 << 16,
        AlphaPreview     = 1 << 17,
        AlphaPreviewHalf = 1 << 18,
        Hdr              = 1 << 19,
        DisplayRgb       = 1 << 20,
        DisplayHsv       = 1 << 21,
        DisplayHex       = 1 << 22,
        Uint8            = 1 << 23,
        Float            = 1 << 24,
        PickerHueBar     = 1 << 25,
        PickerHueWheel   = 1 << 26,
        InputRgb         = 1 << 27,
        InputHsv         = 1 << 28,
        OptionsDefault   = Uint8 | DisplayRgb | InputRgb | PickerHueBar,
        DisplayMask      = DisplayRgb | DisplayHsv | DisplayHex,
        DataTypeMask     = Uint8 | Float,
        PickerMask       = PickerHueWheel | PickerHueBar,
        InputMask        = InputRgb | InputHsv,
    }

    Slider_Flags :: enum i32 {
        None            = 0,
        AlwaysClamp     = 1 << 4,
        Logarithmic     = 1 << 5,
        NoRoundToFormat = 1 << 6,
        NoInput         = 1 << 7,
        InvalidMask     = 0x7000000F,
    }

    Wchar :: distinct u16;
    Wchar16 :: distinct u16;
    Wchar32 :: distinct u32;
    ImID :: distinct u32;

    UI_Style    :: Style
    UI_Color    :: Col
    UI_Vec2     :: Vec2
    UI_Vec4     :: Vec4

    ui_set_window_size_vec2 :: proc(size: Vec2, cond := Cond(0)) { }
    ui_progress_bar :: proc(fraction: f32, size_arg: Vec2, overlay: cstring) { }
    ui_get_content_region_avail :: proc() -> Vec2 { return {} }
    ui_text :: proc(fmt_: cstring, args: ..any) { }
    ui_button :: proc(label: cstring, size := Vec2(Vec2 {0,0})) -> (result: bool) { return }

    ui_begin_table :: proc(str_id: cstring, column: c.int, flags: TableFlags) -> bool { return false }
    ui_table_set_bg_color :: proc(target: Table_Bg_Target, color: u32, column_n := i32(-1))
    ui_table_set_column_index :: proc(column_n: i32) -> bool { return false }
    ui_table_next_column :: proc() -> bool { return false }
    ui_table_next_row :: proc(row_flags := Table_Row_Flags(0), min_row_height := f32(0.0)) { }
    ui_pop_id :: proc() { }
    ui_same_line :: proc() { }
    ui_end_table :: proc() { }
    ui_end :: proc() { }
    ui_end_child :: proc() { }
    ui_pop_style_color :: proc(count: i32) { }
    ui_pop_item_flag :: proc() { }
    ui_set_window_pos :: proc {
        ui_set_window_pos_vec2,
        ui_set_window_pos_str,
    }
    ui_set_window_pos_vec2 :: proc(pos: Vec2, cond := Cond(0)) { }
    ui_set_window_pos_str :: proc(name: cstring, pos: Vec2, cond := Cond(0)) { }
    ui_plot_lines :: proc {
        ui_plot_lines_float_ptr,
        ui_plot_lines_fn_float_ptr,
    }
    ui_plot_lines_ex :: proc(label: cstring, values: ^f32, values_count: c.int, values_offset: c.int, overlay_text: cstring, scale_min: f32, scale_max: f32, graph_size: Vec2, stride: c.int) { }
    ui_plot_lines_float_ptr :: proc(label: cstring, values: ^f32, values_count: i32, values_offset := i32(0), overlay_text := "", scale_min := f32(max(f32)), scale_max := f32(max(f32)), graph_size := Vec2(Vec2 {0,0}), stride := i32(size_of(f32))) { }
    ui_plot_lines_fn_float_ptr :: proc(label: cstring, values_getter: Value_Getter_Proc, data: rawptr, values_count: i32, values_offset: i32, overlay_text: cstring, scale_min: f32, scale_max: f32, graph_size: Vec2) { }
    ui_push_style_color :: proc {
        ui_push_style_color_u32,
        ui_push_style_color_vec4,
    }
    ui_push_style_color_u32 :: proc(idx: Col, col: u32) { }
    ui_push_style_color_vec4 :: proc(idx: Col, col: Vec4) { }

    ui_push_id :: proc {
        ui_push_id_str,
        ui_push_id_str_str,
        ui_push_id_ptr,
        ui_push_id_int,
    }
    ui_push_id_str :: proc(str_id: cstring) { }
    ui_push_id_str_str :: proc(str_id_begin: cstring, str_id_end: cstring) { }
    ui_push_id_ptr :: proc(ptr_id: rawptr) { }
    ui_push_id_int :: proc(int_id: i32) { }

    ui_push_item_width :: proc(item_width: f32) { }
    ui_push_item_flag :: proc(option: Item_Flags, enabled: bool) { }

    ui_input_double :: proc(label: cstring, v: ^f64, step := f64(0.0), step_fast := f64(0.0), format := "%.6f", flags := Input_Text_Flags(0)) -> bool { return false }
    ui_input_float :: proc(label: cstring, v: ^f32, step := f32(0.0), step_fast := f32(0.0), format := "%.3f", flags := Input_Text_Flags(0)) -> bool { return false }
    ui_input_float2 :: proc(label: cstring, v: [2]f32, format := "%.3f", flags := Input_Text_Flags(0)) -> bool { return false }
    ui_input_float3 :: proc(label: cstring, v: [3]f32, format := "%.3f", flags := Input_Text_Flags(0)) -> bool { return false }
    ui_input_float4 :: proc(label: cstring, v: [4]f32, format := "%.3f", flags := Input_Text_Flags(0)) -> bool { return false }
    ui_input_int :: proc(label: cstring, v: ^i32, step := i32(1), step_fast := i32(100), flags := Input_Text_Flags(0)) -> bool { return false }
    ui_input_int2 :: proc(label: cstring, v: [2]i32, flags := Input_Text_Flags(0)) -> bool { return false }
    ui_input_int3 :: proc(label: cstring, v: [3]i32, flags := Input_Text_Flags(0)) -> bool { return false }
    ui_input_int4 :: proc(label: cstring, v: [4]i32, flags := Input_Text_Flags(0)) -> bool { return false }
    ui_input_scalar :: proc(label: cstring, data_type: Data_Type, p_data: rawptr, p_step : rawptr = nil, p_step_fast : rawptr = nil, format := "", flags := Input_Text_Flags(0)) -> bool { return false }
    ui_input_scalar_n :: proc(label: cstring, data_type: Data_Type, p_data: rawptr, components: i32, p_step : rawptr = nil, p_step_fast : rawptr = nil, format := "", flags := Input_Text_Flags(0)) -> bool { return false }
    ui_input_text :: proc(label: cstring, buf: []u8, flags := Input_Text_Flags(0), callback : Input_Text_Callback = nil, user_data : rawptr = nil) -> bool { return false }
    ui_input_text_multiline :: proc(label: cstring, buf: cstring, buf_size: uint, size := Vec2(Vec2 {0,0}), flags := Input_Text_Flags(0), callback : Input_Text_Callback = nil, user_data : rawptr = nil) -> bool { return false }
    ui_input_text_with_hint :: proc(label: cstring, hint: cstring, buf: cstring, buf_size: uint, flags := Input_Text_Flags(0), callback : Input_Text_Callback = nil, user_data : rawptr = nil) -> bool { return false }

    ui_begin :: proc(name: cstring, p_open : ^bool = nil, flags : Window_Flag = .None) -> bool { return false }
    ui_begin_child :: proc {
        ui_begin_child_str,
        ui_begin_child_id,
    }
    ui_begin_child_str :: proc(str_id: cstring, size := Vec2(Vec2 {0,0}), border := bool(false), flags : Window_Flag = {}) -> bool { return false }
    ui_begin_child_id :: proc(id: ImID, size := Vec2(Vec2 {0,0}), border := bool(false), flags : Window_Flag = {}) -> bool { return false }

    ui_tree_node_ex :: proc {
        ui_tree_node_ex_str,
        ui_tree_node_ex_str_str,
        ui_tree_node_ex_ptr,
    }
    ui_tree_node_ex_str :: proc(label: cstring, flags := Tree_Node_Flags(0)) -> bool { return false }
    ui_tree_node_ex_str_str :: proc(str_id: cstring, flags: Tree_Node_Flags, fmt_: cstring, args: ..any) -> bool { return false }
    ui_tree_node_ex_ptr :: proc(ptr_id: rawptr, flags: Tree_Node_Flags, fmt_: cstring, args: ..any) -> bool { return false }

    ui_tree_pop :: proc() { }

    ui_tree_push :: proc {
        ui_tree_push_str,
        ui_tree_push_ptr,
    }
    ui_tree_push_str :: proc(str_id: cstring) { }
    ui_tree_push_ptr :: proc(ptr_id : rawptr = nil) { }

    ui_begin_main_menu_bar :: proc() -> bool { return false }
    ui_begin_menu :: proc(label: cstring, enabled := bool(true)) -> bool { return false }
    ui_begin_menu_bar :: proc() -> bool { return false }
    ui_end_main_menu_bar :: proc() { }
    ui_end_menu :: proc() { }

    ui_push_style_var :: proc {
        ui_push_style_var_float,
        ui_push_style_var_vec2,
    }
    ui_push_style_var_float :: proc(idx: Style_Var, val: f32) { }
    ui_push_style_var_vec2 :: proc(idx: Style_Var, val: UI_Vec2) { }
    ui_pop_style_var :: proc(count := i32(1)) { }

    ui_color_edit3 :: proc(label: cstring, col: ^[3]f32, flags := Color_Edit_Flags(0)) -> bool { return false }
    ui_color_edit4 :: proc(label: cstring, col: ^[4]f32, flags := Color_Edit_Flags(0)) -> bool { return false }
    ui_color_picker3 :: proc(label: cstring, col: ^[3]f32, flags := Color_Edit_Flags(0)) -> bool { return false }
    ui_color_picker4 :: proc(label: cstring, col: ^[4]f32, flags := Color_Edit_Flags(0), ref_col : ^f32 = nil) -> bool { return false }

    ui_slider_float :: proc(label: cstring, v: ^f32, v_min: f32, v_max: f32, format := "%.3f", flags := Slider_Flags(0)) -> bool { return false }
    ui_slider_float2 :: proc(label: cstring, v: ^[2]f32, v_min: f32, v_max: f32, format := "%.3f", flags := Slider_Flags(0)) -> bool { return false }
    ui_slider_float3 :: proc(label: cstring, v: ^[3]f32, v_min: f32, v_max: f32, format := "%.3f", flags := Slider_Flags(0)) -> bool { return false }
    ui_slider_float4 :: proc(label: cstring, v: ^[4]f32, v_min: f32, v_max: f32, format := "%.3f", flags := Slider_Flags(0)) -> bool { return false }

    ui_show_demo_window :: proc(p_open : ^bool = nil) { }

    ui_get_style_color_vec4 :: proc(idx: Col) -> ^Vec4 { return nil }
}
