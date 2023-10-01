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

@(deferred_out=_ui_end)
ui_window :: proc(name: cstring, p_open : ^bool = nil, flags: Window_Flags = {}) -> bool {
    when IMGUI_ENABLE == false {
        return false
    }
    return ui_begin(name, p_open, flags)
}
_ui_end :: proc(collapsed: bool) {
    when IMGUI_ENABLE == false {
        return
    }
    ui_end()
}

@(deferred_out=_ui_child_end)
ui_child :: proc(name: cstring, size: UI_Vec2, border := false, flags: Window_Flags) -> bool {
    return ui_begin_child_str(name, size, border, flags)
}
_ui_child_end :: proc(collapsed: bool) {
    ui_end_child()
}

@(deferred_in=_ui_disable_button_end)
ui_disable_button :: proc(enabled: bool) {
    if enabled {
        color := ui_get_style_color_vec4(UI_Color.Button)
        ui_push_style_color_vec4(UI_Color.Button, { 0.5, 0.5, 0.5, color.w })
    }
    // ui_push_item_flag(.Disabled, enabled) // FIXME:
}
_ui_disable_button_end :: proc(enabled: bool) {
    if enabled {
        ui_pop_style_color(1)
    }
    // ui_pop_item_flag() // FIXME:
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
            if ui_window("Notification", nil, { .NoResize | .NoMove }) {
                ui_set_window_pos_vec2({ _r.rendering_size.x / _r.pixel_density - 200, _r.rendering_size.y / _r.pixel_density - 100 }, .Always)
                ui_text(strings.clone_to_cstring(_r.debug_notification.text, context.temp_allocator))
            }
        }
    }
}

when IMGUI_ENABLE {
    import imgui "../odin-imgui"

    UI_Style                                                   :: imgui.Style
    UI_Color                                                   :: imgui.Col
    UI_Vec2                                                    :: imgui.Vec2
    UI_Vec4                                                    :: imgui.Vec4
    Tree_Node_Flags                                            :: imgui.TreeNodeFlags
    Window_Flags                                               :: imgui.WindowFlags
    InputTextCallbackData                                      :: imgui.InputTextCallbackData

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

    // // ui_add_text                                                :: imgui.AddText
    // ui_begin_child                                             :: imgui.BeginChild
    // // ui_checkbox_flags                                          :: imgui.CheckboxFlags
    ui_collapsing_header                                       :: imgui.CollapsingHeader
    // ui_combo                                                   :: imgui.Combo
    // ui_get_background_draw_list                                :: imgui.GetBackgroundDrawList
    // ui_get_color_u32                                           :: imgui.GetColorU32
    ui_get_foreground_draw_list                                :: imgui.GetForegroundDrawList
    // ui_get_id                                                  :: imgui.GetId
    // ui_is_popup_open                                           :: imgui.IsPopupOpen
    // ui_is_rect_visible                                         :: imgui.IsRectVisible
    // ui_list_box                                                :: imgui.ListBox
    ui_menu_item                                               :: imgui.MenuItem
    // ui_plot_histogram                                          :: imgui.PlotHistogram
    // ui_plot_lines                                              :: imgui.PlotLines
    ui_push_id                                                 :: imgui.PushIDInt
    ui_push_style_color                                        :: imgui.PushStyleColorImVec4
    ui_push_style_var                                          :: imgui.PushStyleVarImVec2
    // ui_radio_button                                            :: imgui.RadioButton
    // ui_selectable                                              :: imgui.Selectable
    // ui_set_scroll_from_pos_x                                   :: imgui.SetScrollFromPosX
    // ui_set_scroll_from_pos_y                                   :: imgui.SetScrollFromPosY
    // ui_set_scroll_x                                            :: imgui.SetScrollX
    // ui_set_scroll_y                                            :: imgui.SetScrollY
    // ui_set_window_collapsed                                    :: imgui.SetWindowCollapsed
    // ui_set_window_focus                                        :: imgui.SetWindowFocus
    // ui_set_window_pos                                          :: imgui.SetWindowPos
    // ui_set_window_size                                         :: imgui.SetWindowSize
    // ui_table_get_column_name                                   :: imgui.TableGetColumnName
    // // ui_tree_node                                               :: imgui.TreeNode
    ui_tree_node_ex                                            :: imgui.TreeNodeEx
    // ui_tree_push                                               :: imgui.TreePush
    // ui_value                                                   :: imgui.Value
    // ui_color_hsv                                               :: imgui.ColorHsv
    // ui_color_set_hsv                                           :: imgui.ColorSetHsv
    // ui_draw_data_clear                                         :: imgui.DrawDataClear
    // ui_draw_data_de_index_all_buffers                          :: imgui.DrawDataDeIndexAllBuffers
    // ui_draw_data_scale_clip_rects                              :: imgui.DrawDataScaleClipRects
    // ui_draw_list_splitter_clear                                :: imgui.DrawListSplitterClear
    // ui_draw_list_splitter_clear_free_memory                    :: imgui.DrawListSplitterClearFreeMemory
    // ui_draw_list_splitter_merge                                :: imgui.DrawListSplitterMerge
    // ui_draw_list_splitter_set_current_channel                  :: imgui.DrawListSplitterSetCurrentChannel
    // ui_draw_list_splitter_split                                :: imgui.DrawListSplitterSplit
    // ui_draw_list_add_bezier_cubic                              :: imgui.DrawListAddBezierCubic
    // ui_draw_list_add_bezier_quadratic                          :: imgui.DrawListAddBezierQuadratic
    // ui_draw_list_add_callback                                  :: imgui.DrawListAddCallback
    // ui_draw_list_add_circle                                    :: imgui.DrawListAddCircle
    // ui_draw_list_add_circle_filled                             :: imgui.DrawList_AddCircleFilled
    // ui_draw_list_add_convex_poly_filled                        :: imgui.DrawList_AddConvexPolyFilled
    // ui_draw_list_add_draw_cmd                                  :: imgui.DrawList_AddDrawCmd
    // ui_draw_list_add_image                                     :: imgui.DrawList_AddImage
    // ui_draw_list_add_image_quad                                :: imgui.DrawList_AddImageQuad
    // ui_draw_list_add_image_rounded                             :: imgui.DrawList_AddImageRounded
    // ui_draw_list_add_line                                      :: imgui.DrawList_AddLine
    // ui_draw_list_add_ngon                                      :: imgui.DrawList_AddNgon
    // ui_draw_list_add_ngon_filled                               :: imgui.DrawList_AddNgonFilled
    // ui_draw_list_add_polyline                                  :: imgui.DrawList_AddPolyline
    // ui_draw_list_add_quad                                      :: imgui.DrawList_AddQuad
    // ui_draw_list_add_quad_filled                               :: imgui.DrawList_AddQuadFilled
    // ui_draw_list_add_rect                                      :: imgui.DrawList_AddRect
    ui_draw_list_add_rect_filled                               :: imgui.DrawList_AddRectFilled
    // ui_draw_list_add_rect_filled_multi_color                   :: imgui.DrawList_AddRectFilledMultiColor
    // // ui_draw_list_add_text_vec2                                 :: imgui.DrawList_AddTextVec2
    // // ui_draw_list_add_text_font_ptr                             :: imgui.DrawList_AddTextFontPtr
    // ui_draw_list_add_triangle                                  :: imgui.DrawList_AddTriangle
    // ui_draw_list_add_triangle_filled                           :: imgui.DrawList_AddTriangleFilled
    // ui_draw_list_channels_merge                                :: imgui.DrawList_ChannelsMerge
    // ui_draw_list_channels_set_current                          :: imgui.DrawList_ChannelsSetCurrent
    // ui_draw_list_channels_split                                :: imgui.DrawList_ChannelsSplit
    // ui_draw_list_clone_output                                  :: imgui.DrawList_CloneOutput
    // ui_draw_list_get_clip_rect_max                             :: imgui.DrawList_GetClipRectMax
    // ui_draw_list_get_clip_rect_min                             :: imgui.DrawList_GetClipRectMin
    // ui_draw_list_path_arc_to                                   :: imgui.DrawList_PathArcTo
    // ui_draw_list_path_arc_to_fast                              :: imgui.DrawList_PathArcToFast
    // ui_draw_list_path_bezier_cubic_curve_to                    :: imgui.DrawList_PathBezierCubicCurveTo
    // ui_draw_list_path_bezier_quadratic_curve_to                :: imgui.DrawList_PathBezierQuadraticCurveTo
    // ui_draw_list_path_clear                                    :: imgui.DrawList_PathClear
    // ui_draw_list_path_fill_convex                              :: imgui.DrawList_PathFillConvex
    // ui_draw_list_path_line_to                                  :: imgui.DrawList_PathLineTo
    // ui_draw_list_path_line_to_merge_duplicate                  :: imgui.DrawList_PathLineToMergeDuplicate
    // ui_draw_list_path_rect                                     :: imgui.DrawList_PathRect
    // ui_draw_list_path_stroke                                   :: imgui.DrawList_PathStroke
    // ui_draw_list_pop_clip_rect                                 :: imgui.DrawList_PopClipRect
    // // ui_draw_list_pop_texture_id                                :: imgui.DrawList_PopTextureId
    // // ui_draw_list_prim_quad_uv                                  :: imgui.DrawList_PrimQuadUv
    // ui_draw_list_prim_rect                                     :: imgui.DrawList_PrimRect
    // // ui_draw_list_prim_rect_uv                                  :: imgui.DrawList_PrimRectUv
    // ui_draw_list_prim_reserve                                  :: imgui.DrawList_PrimReserve
    // ui_draw_list_prim_unreserve                                :: imgui.DrawList_PrimUnreserve
    // ui_draw_list_prim_vtx                                      :: imgui.DrawList_PrimVtx
    // ui_draw_list_prim_write_idx                                :: imgui.DrawList_PrimWriteIdx
    // ui_draw_list_prim_write_vtx                                :: imgui.DrawList_PrimWriteVtx
    // ui_draw_list_push_clip_rect                                :: imgui.DrawList_PushClipRect
    // ui_draw_list_push_clip_rect_full_screen                    :: imgui.DrawList_PushClipRectFullScreen
    // ui_draw_list_push_texture_id                               :: imgui.DrawList_PushTextureId
    // ui_draw_list_calc_circle_auto_segment_count                :: imgui.DrawList_CalcCircleAutoSegmentCount
    // ui_draw_list_clear_free_memory                             :: imgui.DrawList_ClearFreeMemory
    // ui_draw_list_on_changed_clip_rect                          :: imgui.DrawList__OnChangedClipRect
    // ui_draw_list_on_changed_texture_id                         :: imgui.DrawList__OnChangedTextureID
    // ui_draw_list_on_changed_vtx_offset                         :: imgui.DrawList__OnChangedVtxOffset
    // ui_draw_list_path_arc_to_fast_ex                           :: imgui.DrawList__PathArcToFastEx
    // ui_draw_list_path_arc_to_n                                 :: imgui.DrawList__PathArcToN
    // ui_draw_list_pop_unused_draw_cmd                           :: imgui.DrawList__PopUnusedDrawCmd
    // ui_draw_list_reset_for_new_frame                           :: imgui.DrawList_ResetForNewFrame
    // ui_font_atlas_custom_rect_is_packed                        :: imgui.FontAtlasCustomRectIsPacked
    // ui_font_atlas_add_custom_rect_font_glyph                   :: imgui.FontAtlasAddCustomRectFontGlyph
    // ui_font_atlas_add_custom_rect_regular                      :: imgui.FontAtlasAddCustomRectRegular
    // ui_font_atlas_add_font                                     :: imgui.FontAtlasAddFont
    // ui_font_atlas_add_font_default                             :: imgui.FontAtlasAddFontDefault
    // ui_font_atlas_add_font_from_file_ttf                       :: imgui.FontAtlasAddFontFromFileTtf
    // ui_font_atlas_add_font_from_memory_compressed_base85ttf    :: imgui.FontAtlasAddFontFromMemoryCompressedBase85ttf
    // ui_font_atlas_add_font_from_memory_compressed_ttf          :: imgui.FontAtlasAddFontFromMemoryCompressedTtf
    // ui_font_atlas_add_font_from_memory_ttf                     :: imgui.FontAtlasAddFontFromMemoryTtf
    // ui_font_atlas_build                                        :: imgui.FontAtlasBuild
    // ui_font_atlas_calc_custom_rect_uv                          :: imgui.FontAtlasCalcCustomRectUv
    // ui_font_atlas_clear                                        :: imgui.FontAtlasClear
    // ui_font_atlas_clear_fonts                                  :: imgui.FontAtlasClearFonts
    // ui_font_atlas_clear_input_data                             :: imgui.FontAtlasClearInputData
    // ui_font_atlas_clear_tex_data                               :: imgui.FontAtlasClearTexData
    // ui_font_atlas_get_custom_rect_by_index                     :: imgui.FontAtlasGetCustomRectByIndex
    // ui_font_atlas_get_glyph_ranges_chinese_full                :: imgui.FontAtlasGetGlyphRangesChineseFull
    // ui_font_atlas_get_glyph_ranges_chinese_simplified_common   :: imgui.FontAtlasGetGlyphRangesChineseSimplifiedCommon
    // ui_font_atlas_get_glyph_ranges_cyrillic                    :: imgui.FontAtlasGetGlyphRangesCyrillic
    // ui_font_atlas_get_glyph_ranges_default                     :: imgui.FontAtlasGetGlyphRangesDefault
    // ui_font_atlas_get_glyph_ranges_japanese                    :: imgui.FontAtlasGetGlyphRangesJapanese
    // ui_font_atlas_get_glyph_ranges_korean                      :: imgui.FontAtlasGetGlyphRangesKorean
    // ui_font_atlas_get_glyph_ranges_thai                        :: imgui.FontAtlasGetGlyphRangesThai
    // ui_font_atlas_get_glyph_ranges_vietnamese                  :: imgui.FontAtlasGetGlyphRangesVietnamese
    // ui_font_atlas_get_mouse_cursor_tex_data                    :: imgui.FontAtlasGetMouseCursorTexData
    // ui_font_atlas_get_tex_data_as_alpha8                       :: imgui.FontAtlasGetTexDataAsAlpha8
    // ui_font_atlas_get_tex_data_as_rgba32                       :: imgui.FontAtlasGetTexDataAsRgba32
    // ui_font_atlas_is_built                                     :: imgui.FontAtlasIsBuilt
    // ui_font_atlas_set_tex_id                                   :: imgui.FontAtlasSetTexId
    // ui_font_glyph_ranges_builder_add_char                      :: imgui.FontGlyphRangesBuilderAddChar
    // ui_font_glyph_ranges_builder_add_ranges                    :: imgui.FontGlyphRangesBuilderAddRanges
    // ui_font_glyph_ranges_builder_add_text                      :: imgui.FontGlyphRangesBuilderAddText
    // ui_font_glyph_ranges_builder_build_ranges                  :: imgui.FontGlyphRangesBuilderBuildRanges
    // ui_font_glyph_ranges_builder_clear                         :: imgui.FontGlyphRangesBuilderClear
    // ui_font_glyph_ranges_builder_get_bit                       :: imgui.FontGlyphRangesBuilderGetBit
    // ui_font_glyph_ranges_builder_set_bit                       :: imgui.FontGlyphRangesBuilderSetBit
    // ui_font_add_glyph                                          :: imgui.FontAddGlyph
    // ui_font_add_remap_char                                     :: imgui.FontAddRemapChar
    // ui_font_build_lookup_table                                 :: imgui.FontBuildLookupTable
    // ui_font_calc_text_size_a                                   :: imgui.FontCalcTextSizeA
    // ui_font_calc_word_wrap_position_a                          :: imgui.FontCalcWordWrapPositionA
    // ui_font_clear_output_data                                  :: imgui.FontClearOutputData
    // ui_font_find_glyph                                         :: imgui.FontFindGlyph
    // ui_font_find_glyph_no_fallback                             :: imgui.FontFindGlyphNoFallback
    // ui_font_get_char_advance                                   :: imgui.FontGetCharAdvance
    // ui_font_get_debug_name                                     :: imgui.FontGetDebugName
    // ui_font_grow_index                                         :: imgui.FontGrowIndex
    // ui_font_is_glyph_range_unused                              :: imgui.FontIsGlyphRangeUnused
    // ui_font_is_loaded                                          :: imgui.FontIsLoaded
    // ui_font_render_char                                        :: imgui.FontRenderChar
    // ui_font_render_text                                        :: imgui.FontRenderText
    // ui_font_set_fallback_char                                  :: imgui.FontSetFallbackChar
    // ui_font_set_glyph_visible                                  :: imgui.FontSetGlyphVisible
    // ui_io_add_input_character                                  :: imgui.IoAddInputCharacter
    // ui_io_add_input_character_utf16                            :: imgui.IoAddInputCharacterUtf16
    // ui_io_add_input_characters_utf8                            :: imgui.IoAddInputCharactersUtf8
    // ui_io_clear_input_characters                               :: imgui.IoClearInputCharacters
    // ui_input_text_callback_data_clear_selection                :: imgui.InputTextCallbackDataClearSelection
    // ui_input_text_callback_data_delete_chars                   :: imgui.InputTextCallbackDataDeleteChars
    // ui_input_text_callback_data_has_selection                  :: imgui.InputTextCallbackDataHasSelection
    // ui_input_text_callback_data_insert_chars                   :: imgui.InputTextCallbackDataInsertChars
    // ui_input_text_callback_data_select_all                     :: imgui.InputTextCallbackDataSelectAll
    // ui_list_clipper_begin                                      :: imgui.ListClipperBegin
    // ui_list_clipper_end                                        :: imgui.ListClipperEnd
    // ui_list_clipper_step                                       :: imgui.ListClipperStep
    // ui_payload_clear                                           :: imgui.PayloadClear
    // ui_payload_is_data_type                                    :: imgui.PayloadIsDataType
    // ui_payload_is_delivery                                     :: imgui.PayloadIsDelivery
    // ui_payload_is_preview                                      :: imgui.PayloadIsPreview
    // ui_storage_build_sort_by_key                               :: imgui.StorageBuildSortByKey
    // ui_storage_clear                                           :: imgui.StorageClear
    // ui_storage_get_bool                                        :: imgui.StorageGetBool
    // ui_storage_get_bool_ref                                    :: imgui.StorageGetBoolRef
    // ui_storage_get_float                                       :: imgui.StorageGetFloat
    // ui_storage_get_float_ref                                   :: imgui.StorageGetFloatRef
    // ui_storage_get_int                                         :: imgui.StorageGetInt
    // ui_storage_get_int_ref                                     :: imgui.StorageGetIntRef
    // ui_storage_get_void_ptr                                    :: imgui.StorageGetVoidPtr
    // ui_storage_get_void_ptr_ref                                :: imgui.StorageGetVoidPtrRef
    // ui_storage_set_all_int                                     :: imgui.StorageSetAllInt
    // ui_storage_set_bool                                        :: imgui.StorageSetBool
    // ui_storage_set_float                                       :: imgui.StorageSetFloat
    // ui_storage_set_int                                         :: imgui.StorageSetInt
    // ui_storage_set_void_ptr                                    :: imgui.StorageSetVoidPtr
    // ui_style_scale_all_sizes                                   :: imgui.StyleScaleAllSizes
    // ui_text_buffer_append                                      :: imgui.TextBufferAppend
    // ui_text_buffer_appendf                                     :: imgui.TextBufferAppendf
    // ui_text_buffer_begin                                       :: imgui.TextBufferBegin
    // ui_text_buffer_c_str                                       :: imgui.TextBufferCStr
    // ui_text_buffer_clear                                       :: imgui.TextBufferClear
    // ui_text_buffer_empty                                       :: imgui.TextBufferEmpty
    // ui_text_buffer_end                                         :: imgui.TextBufferEnd
    // ui_text_buffer_reserve                                     :: imgui.TextBufferReserve
    // ui_text_buffer_size                                        :: imgui.TextBufferSize
    // ui_text_filter_build                                       :: imgui.TextFilterBuild
    // ui_text_filter_clear                                       :: imgui.TextFilterClear
    // ui_text_filter_draw                                        :: imgui.TextFilterDraw
    // ui_text_filter_is_active                                   :: imgui.TextFilterIsActive
    // ui_text_filter_pass_filter                                 :: imgui.TextFilterPassFilter
    // ui_text_range_empty                                        :: imgui.TextRangeEmpty
    // ui_text_range_split                                        :: imgui.TextRangeSplit
    // ui_viewport_get_center                                     :: imgui.ViewportGetCenter
    // ui_viewport_get_work_center                                :: imgui.ViewportGetWorkCenter
    // ui_accept_drag_drop_payload                                :: imgui.AcceptDragDropPayload
    // ui_align_text_to_frame_padding                             :: imgui.AlignTextToFramePadding
    // ui_arrow_button                                            :: imgui.ArrowButton
    ui_begin                                                   :: imgui.Begin
    ui_begin_child_str                                         :: imgui.BeginChild
    // ui_begin_child_id                                          :: imgui.BeginChildId
    // ui_begin_child_frame                                       :: imgui.BeginChildFrame
    // ui_begin_combo                                             :: imgui.BeginCombo
    // ui_begin_drag_drop_source                                  :: imgui.BeginDragDropSource
    // ui_begin_drag_drop_target                                  :: imgui.BeginDragDropTarget
    // ui_begin_group                                             :: imgui.BeginGroup
    // ui_begin_list_box                                          :: imgui.BeginListBox
    ui_begin_main_menu_bar                                     :: imgui.BeginMainMenuBar
    ui_begin_menu                                              :: imgui.BeginMenuEx
    // ui_begin_menu_bar                                          :: imgui.BeginMenuBar
    // ui_begin_popup                                             :: imgui.BeginPopup
    // ui_begin_popup_context_item                                :: imgui.BeginPopupContextItem
    // ui_begin_popup_context_void                                :: imgui.BeginPopupContextVoid
    // ui_begin_popup_context_window                              :: imgui.BeginPopupContextWindow
    // ui_begin_popup_modal                                       :: imgui.BeginPopupModal
    // ui_begin_tab_bar                                           :: imgui.BeginTabBar
    // ui_begin_tab_item                                          :: imgui.BeginTabItem
    ui_begin_table                                             :: imgui.BeginTable
    // ui_begin_tooltip                                           :: imgui.BeginTooltip
    // ui_bullet                                                  :: imgui.Bullet
    // ui_bullet_text                                             :: imgui.BulletText
    ui_button                                                  :: imgui.Button
    // ui_calc_item_width                                         :: imgui.CalcItemWidth
    // ui_calc_list_clipping                                      :: imgui.CalcListClipping
    // ui_calc_text_size                                          :: imgui.CalcTextSize
    // ui_capture_keyboard_from_app                               :: imgui.CaptureKeyboardFromApp
    // ui_capture_mouse_from_app                                  :: imgui.CaptureMouseFromApp
    ui_checkbox                                                :: imgui.Checkbox
    // ui_checkbox_flags_int_ptr                                  :: imgui.CheckboxFlagsIntPtr
    // ui_checkbox_flags_uint_ptr                                 :: imgui.CheckboxFlagsUintPtr
    // ui_close_current_popup                                     :: imgui.CloseCurrentPopup
    // ui_collapsing_header_tree_node_flags                       :: imgui.CollapsingHeaderTreeNodeFlags
    // ui_collapsing_header_bool_ptr                              :: imgui.CollapsingHeaderBoolPtr
    // ui_color_button                                            :: imgui.ColorButton
    // ui_color_convert_float4to_u32                              :: imgui.ColorConvertFloat4toU32
    // ui_color_convert_hs_vto_rgb                                :: imgui.ColorConvertHsVtoRgb
    // ui_color_convert_rg_bto_hsv                                :: imgui.ColorConvertRgBtoHsv
    // ui_color_convert_u32to_float4                              :: imgui.ColorConvertU32toFloat4
    // ui_color_edit3                                             :: imgui.ColorEdit3
    ui_color_edit4                                             :: imgui.ColorEdit4
    // ui_color_picker3                                           :: imgui.ColorPicker3
    // ui_color_picker4                                           :: imgui.ColorPicker4
    // ui_columns                                                 :: imgui.Columns
    // ui_combo_str_arr                                           :: imgui.ComboStrArr
    // ui_combo_str                                               :: imgui.ComboStr
    // ui_combo_fn_bool_ptr                                       :: imgui.ComboFnBoolPtr
    // ui_create_context                                          :: imgui.CreateContext
    // ui_debug_check_version_and_data_layout                     :: imgui.DebugCheckVersionAndDataLayout
    // ui_destroy_context                                         :: imgui.DestroyContext
    // ui_drag_float                                              :: imgui.DragFloat
    // ui_drag_float2                                             :: imgui.DragFloat2
    // ui_drag_float3                                             :: imgui.DragFloat3
    // ui_drag_float4                                             :: imgui.DragFloat4
    // ui_drag_float_range2                                       :: imgui.DragFloatRange2
    // ui_drag_int                                                :: imgui.DragInt
    // ui_drag_int2                                               :: imgui.DragInt2
    // ui_drag_int3                                               :: imgui.DragInt3
    // ui_drag_int4                                               :: imgui.DragInt4
    // ui_drag_int_range2                                         :: imgui.DragIntRange2
    // ui_drag_scalar                                             :: imgui.DragScalar
    // ui_drag_scalar_n                                           :: imgui.DragScalarN
    ui_dummy                                                   :: imgui.Dummy
    ui_end                                                     :: imgui.End
    ui_end_child                                               :: imgui.EndChild
    // ui_end_child_frame                                         :: imgui.EndChildFrame
    // ui_end_combo                                               :: imgui.EndCombo
    // ui_end_drag_drop_source                                    :: imgui.EndDragDropSource
    // ui_end_drag_drop_target                                    :: imgui.EndDragDropTarget
    // ui_end_frame                                               :: imgui.EndFrame
    // ui_end_group                                               :: imgui.EndGroup
    // ui_end_list_box                                            :: imgui.EndListBox
    ui_end_main_menu_bar                                       :: imgui.EndMainMenuBar
    ui_end_menu                                                :: imgui.EndMenu
    // ui_end_menu_bar                                            :: imgui.EndMenuBar
    // ui_end_popup                                               :: imgui.EndPopup
    // ui_end_tab_bar                                             :: imgui.EndTabBar
    // ui_end_tab_item                                            :: imgui.EndTabItem
    ui_end_table                                               :: imgui.EndTable
    // ui_end_tooltip                                             :: imgui.EndTooltip
    // ui_get_allocator_functions                                 :: imgui.GetAllocatorFunctions
    // ui_get_background_draw_list_nil                            :: imgui.GetBackgroundDrawListNil
    // ui_get_clipboard_text                                      :: imgui.GetClipboardText
    // ui_get_color_u32_col                                       :: imgui.GetColorU32Col
    ui_get_color_u32_vec4                                      :: imgui.GetColorU32ImVec4
    // ui_get_color_u32_u32                                       :: imgui.GetColorU32U32
    // ui_get_column_index                                        :: imgui.GetColumnIndex
    // ui_get_column_offset                                       :: imgui.GetColumnOffset
    // ui_get_column_width                                        :: imgui.GetColumnWidth
    // ui_get_columns_count                                       :: imgui.GetColumnsCount
    ui_get_content_region_avail                                :: imgui.GetContentRegionAvail
    // ui_get_content_region_max                                  :: imgui.GetContentRegionMax
    // ui_get_current_context                                     :: imgui.GetCurrentContext
    // ui_get_cursor_pos                                          :: imgui.GetCursorPos
    // ui_get_cursor_pos_x                                        :: imgui.GetCursorPosX
    // ui_get_cursor_pos_y                                        :: imgui.GetCursorPosY
    // ui_get_cursor_screen_pos                                   :: imgui.GetCursorScreenPos
    // ui_get_cursor_start_pos                                    :: imgui.GetCursorStartPos
    // ui_get_drag_drop_payload                                   :: imgui.GetDragDropPayload
    // ui_get_draw_data                                           :: imgui.GetDrawData
    // ui_get_draw_list_shared_data                               :: imgui.GetDrawListSharedData
    // ui_get_font                                                :: imgui.GetFont
    // ui_get_font_size                                           :: imgui.GetFontSize
    // ui_get_font_tex_uv_white_pixel                             :: imgui.GetFontTexUvWhitePixel
    // ui_get_foreground_draw_list_nil                            :: imgui.GetForegroundDrawListNil
    // ui_get_frame_count                                         :: imgui.GetFrameCount
    // ui_get_frame_height                                        :: imgui.GetFrameHeight
    // ui_get_frame_height_with_spacing                           :: imgui.GetFrameHeightWithSpacing
    // ui_get_id_str                                              :: imgui.GetIdStr
    // ui_get_id_str_str                                          :: imgui.GetIdStrStr
    // ui_get_id_ptr                                              :: imgui.GetIdPtr
    // ui_get_io                                                  :: imgui.GetIo
    // ui_get_item_rect_max                                       :: imgui.GetItemRectMax
    ui_get_item_rect_min                                       :: imgui.GetItemRectMin
    // ui_get_item_rect_size                                      :: imgui.GetItemRectSize
    // ui_get_key_index                                           :: imgui.GetKeyIndex
    // ui_get_key_pressed_amount                                  :: imgui.GetKeyPressedAmount
    // ui_get_main_viewport                                       :: imgui.GetMainViewport
    // ui_get_mouse_cursor                                        :: imgui.GetMouseCursor
    // ui_get_mouse_drag_delta                                    :: imgui.GetMouseDragDelta
    // ui_get_mouse_pos                                           :: imgui.GetMousePos
    // ui_get_mouse_pos_on_opening_current_popup                  :: imgui.GetMousePosOnOpeningCurrentPopup
    // ui_get_scroll_max_x                                        :: imgui.GetScrollMaxX
    // ui_get_scroll_max_y                                        :: imgui.GetScrollMaxY
    // ui_get_scroll_x                                            :: imgui.GetScrollX
    // ui_get_scroll_y                                            :: imgui.GetScrollY
    // ui_get_state_storage                                       :: imgui.GetStateStorage
    // ui_get_style                                               :: imgui.GetStyle
    // ui_get_style_color_name                                    :: imgui.GetStyleColorName
    ui_get_style_color_vec4                                    :: imgui.GetStyleColorVec4
    // ui_get_text_line_height                                    :: imgui.GetTextLineHeight
    // ui_get_text_line_height_with_spacing                       :: imgui.GetTextLineHeightWithSpacing
    // ui_get_time                                                :: imgui.GetTime
    // ui_get_tree_node_to_label_spacing                          :: imgui.GetTreeNodeToLabelSpacing
    // ui_get_version                                             :: imgui.GetVersion
    // ui_get_window_content_region_max                           :: imgui.GetWindowContentRegionMax
    // ui_get_window_content_region_min                           :: imgui.GetWindowContentRegionMin
    // ui_get_window_content_region_width                         :: imgui.GetWindowContentRegionWidth
    // ui_get_window_draw_list                                    :: imgui.GetWindowDrawList
    // ui_get_window_height                                       :: imgui.GetWindowHeight
    ui_get_window_pos                                          :: imgui.GetWindowPos
    ui_get_window_size                                         :: imgui.GetWindowSize
    // ui_get_window_width                                        :: imgui.GetWindowWidth
    ui_image                                                   :: imgui.ImageEx
    // ui_image_button                                            :: imgui.ImageButton
    // ui_indent                                                  :: imgui.Indent
    // ui_input_double                                            :: imgui.InputDouble
    ui_input_float                                             :: imgui.InputFloat
    ui_input_float2                                            :: imgui.InputFloat2
    ui_input_float3                                            :: imgui.InputFloat3
    ui_input_float4                                            :: imgui.InputFloat4
    ui_input_int                                               :: imgui.InputInt
    ui_input_int2                                              :: imgui.InputInt2
    ui_input_int3                                              :: imgui.InputInt3
    ui_input_int4                                              :: imgui.InputInt4
    // ui_input_scalar                                            :: imgui.InputScalar
    // ui_input_scalar_n                                          :: imgui.InputScalarN
    // ui_input_text                                              :: imgui.InputText
    // ui_input_text_multiline                                    :: imgui.InputTextMultiline
    // ui_input_text_with_hint                                    :: imgui.InputTextWithHint
    // ui_invisible_button                                        :: imgui.InvisibleButton
    // ui_is_any_item_active                                      :: imgui.IsAnyItemActive
    // ui_is_any_item_focused                                     :: imgui.IsAnyItemFocused
    // ui_is_any_item_hovered                                     :: imgui.IsAnyItemHovered
    // ui_is_any_mouse_down                                       :: imgui.IsAnyMouseDown
    // ui_is_item_activated                                       :: imgui.IsItemActivated
    // ui_is_item_active                                          :: imgui.IsItemActive
    // ui_is_item_clicked                                         :: imgui.IsItemClicked
    // ui_is_item_deactivated                                     :: imgui.IsItemDeactivated
    // ui_is_item_deactivated_after_edit                          :: imgui.IsItemDeactivatedAfterEdit
    // ui_is_item_edited                                          :: imgui.IsItemEdited
    // ui_is_item_focused                                         :: imgui.IsItemFocused
    // ui_is_item_hovered                                         :: imgui.IsItemHovered
    // ui_is_item_toggled_open                                    :: imgui.IsItemToggledOpen
    // ui_is_item_visible                                         :: imgui.IsItemVisible
    // ui_is_key_down                                             :: imgui.IsKeyDown
    // ui_is_key_pressed                                          :: imgui.IsKeyPressed
    // ui_is_key_released                                         :: imgui.IsKeyReleased
    ui_is_mouse_clicked                                        :: imgui.IsMouseClicked
    // ui_is_mouse_double_clicked                                 :: imgui.IsMouseDoubleClicked
    // ui_is_mouse_down                                           :: imgui.IsMouseDown
    // ui_is_mouse_dragging                                       :: imgui.IsMouseDragging
    ui_is_mouse_hovering_rect                                  :: imgui.IsMouseHoveringRect
    // ui_is_mouse_pos_valid                                      :: imgui.IsMousePosValid
    // ui_is_mouse_released                                       :: imgui.IsMouseReleased
    // ui_is_popup_open_str                                       :: imgui.IsPopupOpenStr
    // ui_is_rect_visible_nil                                     :: imgui.IsRectVisibleNil
    // ui_is_rect_visible_vec2                                    :: imgui.IsRectVisibleVec2
    // ui_is_window_appearing                                     :: imgui.IsWindowAppearing
    // ui_is_window_collapsed                                     :: imgui.IsWindowCollapsed
    // ui_is_window_focused                                       :: imgui.IsWindowFocused
    // ui_is_window_hovered                                       :: imgui.IsWindowHovered
    // ui_label_text                                              :: imgui.LabelText
    // ui_list_box_str_arr                                        :: imgui.ListBoxStrArr
    // ui_list_box_fn_bool_ptr                                    :: imgui.ListBoxFnBoolPtr
    // ui_load_ini_settings_from_disk                             :: imgui.LoadIniSettingsFromDisk
    // ui_load_ini_settings_from_memory                           :: imgui.LoadIniSettingsFromMemory
    // ui_log_buttons                                             :: imgui.LogButtons
    // ui_log_finish                                              :: imgui.LogFinish
    // ui_log_text                                                :: imgui.LogText
    // ui_log_to_clipboard                                        :: imgui.LogToClipboard
    // ui_log_to_file                                             :: imgui.LogToFile
    // ui_log_to_tty                                              :: imgui.LogToTty
    // ui_mem_alloc                                               :: imgui.MemAlloc
    // ui_mem_free                                                :: imgui.MemFree
    ui_menu_item_ex                                               :: imgui.MenuItemEx
    ui_menu_item_bool_ptr                                         :: imgui.MenuItemBoolPtr
    // ui_new_frame                                               :: imgui.NewFrame
    // ui_new_line                                                :: imgui.NewLine
    // ui_next_column                                             :: imgui.NextColumn
    // ui_open_popup                                              :: imgui.OpenPopup
    // ui_open_popup_on_item_click                                :: imgui.OpenPopupOnItemClick
    // ui_plot_histogram_float_ptr                                :: imgui.PlotHistogramFloatPtr
    // ui_plot_histogram_fn_float_ptr                             :: imgui.PlotHistogramFnFloatPtr
    ui_plot_lines_ex                                              :: imgui.PlotLinesEx
    // ui_plot_lines_float_ptr                                    :: imgui.PlotLinesCallback
    ui_plot_lines_fn_float_ptr                                 :: imgui.PlotLinesCallbackEx
    // ui_pop_allow_keyboard_focus                                :: imgui.PopAllowKeyboardFocus
    // ui_pop_button_repeat                                       :: imgui.PopButtonRepeat
    // ui_pop_clip_rect                                           :: imgui.PopClipRect
    // ui_pop_font                                                :: imgui.PopFont
    ui_pop_id                                                  :: imgui.PopID
    ui_pop_item_width                                          :: imgui.PopItemWidth
    ui_pop_style_color                                         :: imgui.PopStyleColorEx
    ui_pop_style_var                                           :: imgui.PopStyleVarEx
    // ui_pop_text_wrap_pos                                       :: imgui.PopTextWrapPos
    ui_progress_bar                                            :: imgui.ProgressBar
    // ui_push_allow_keyboard_focus                               :: imgui.PushAllowKeyboardFocus
    // ui_push_button_repeat                                      :: imgui.PushButtonRepeat
    // ui_push_clip_rect                                          :: imgui.PushClipRect
    // ui_push_font                                               :: imgui.PushFont
    // ui_push_id_str                                             :: imgui.PushIdStr
    // ui_push_id_str_str                                         :: imgui.PushIdStrStr
    // ui_push_id_ptr                                             :: imgui.PushIdPtr
    // ui_push_id_int                                             :: imgui.PushIdInt
    ui_push_item_width                                         :: imgui.PushItemWidth
    // ui_push_item_flag                                          :: imgui.PushItemFlag
    // ui_pop_item_flag                                           :: imgui.PopItemFlag
    // ui_push_style_color_u32                                    :: imgui.PushStyleColorU32
    ui_push_style_color_vec4                                   :: imgui.PushStyleColorImVec4
    // ui_push_style_var_float                                    :: imgui.PushStyleVarFloat
    // ui_push_style_var_vec2                                     :: imgui.PushStyleVarVec2
    // ui_push_text_wrap_pos                                      :: imgui.PushTextWrapPos
    // ui_radio_button_bool                                       :: imgui.RadioButtonBool
    // ui_radio_button_int_ptr                                    :: imgui.RadioButtonIntPtr
    // ui_render                                                  :: imgui.Render
    // ui_reset_mouse_drag_delta                                  :: imgui.ResetMouseDragDelta
    ui_same_line                                               :: imgui.SameLine
    ui_same_line_ex                                            :: imgui.SameLineEx
    // ui_save_ini_settings_to_disk                               :: imgui.SaveIniSettingsToDisk
    // ui_save_ini_settings_to_memory                             :: imgui.SaveIniSettingsToMemory
    // ui_selectable_bool                                         :: imgui.SelectableBool
    // ui_selectable_bool_ptr                                     :: imgui.SelectableBoolPtr
    // ui_separator                                               :: imgui.Separator
    // ui_set_allocator_functions                                 :: imgui.SetAllocatorFunctions
    // ui_set_clipboard_text                                      :: imgui.SetClipboardText
    // ui_set_color_edit_options                                  :: imgui.SetColorEditOptions
    // ui_set_column_offset                                       :: imgui.SetColumnOffset
    // ui_set_column_width                                        :: imgui.SetColumnWidth
    // ui_set_current_context                                     :: imgui.SetCurrentContext
    // ui_set_cursor_pos                                          :: imgui.SetCursorPos
    // ui_set_cursor_pos_x                                        :: imgui.SetCursorPosX
    // ui_set_cursor_pos_y                                        :: imgui.SetCursorPosY
    // ui_set_cursor_screen_pos                                   :: imgui.SetCursorScreenPos
    // ui_set_drag_drop_payload                                   :: imgui.SetDragDropPayload
    // ui_set_item_allow_overlap                                  :: imgui.SetItemAllowOverlap
    // ui_set_item_default_focus                                  :: imgui.SetItemDefaultFocus
    // ui_set_keyboard_focus_here                                 :: imgui.SetKeyboardFocusHere
    // ui_set_mouse_cursor                                        :: imgui.SetMouseCursor
    // ui_set_next_item_open                                      :: imgui.SetNextItemOpen
    // ui_set_next_item_width                                     :: imgui.SetNextItemWidth
    // ui_set_next_window_bg_alpha                                :: imgui.SetNextWindowBgAlpha
    // ui_set_next_window_collapsed                               :: imgui.SetNextWindowCollapsed
    // ui_set_next_window_content_size                            :: imgui.SetNextWindowContentSize
    // ui_set_next_window_focus                                   :: imgui.SetNextWindowFocus
    // ui_set_next_window_pos                                     :: imgui.SetNextWindowPos
    // ui_set_next_window_size                                    :: imgui.SetNextWindowSize
    // ui_set_next_window_size_constraints                        :: imgui.SetNextWindowSizeConstraints
    // ui_set_scroll_from_pos_x_float                             :: imgui.SetScrollFromPosXFloat
    // ui_set_scroll_from_pos_y_float                             :: imgui.SetScrollFromPosYFloat
    // ui_set_scroll_here_x                                       :: imgui.SetScrollHereX
    // ui_set_scroll_here_y                                       :: imgui.SetScrollHereY
    // ui_set_scroll_x_float                                      :: imgui.SetScrollXFloat
    // ui_set_scroll_y_float                                      :: imgui.SetScrollYFloat
    // ui_set_state_storage                                       :: imgui.SetStateStorage
    // ui_set_tab_item_closed                                     :: imgui.SetTabItemClosed
    // ui_set_tooltip                                             :: imgui.SetTooltip
    // ui_set_window_collapsed_bool                               :: imgui.SetWindowCollapsedBool
    // ui_set_window_collapsed_str                                :: imgui.SetWindowCollapsedStr
    // ui_set_window_focus_nil                                    :: imgui.SetWindowFocusNil
    // ui_set_window_focus_str                                    :: imgui.SetWindowFocusStr
    // ui_set_window_font_scale                                   :: imgui.SetWindowFontScale
    ui_set_window_pos_vec2                                     :: imgui.SetWindowPos
    // ui_set_window_pos_str                                      :: imgui.SetWindowPosStr
    ui_set_window_size_vec2                                    :: imgui.SetWindowSize
    // ui_set_window_size_str                                     :: imgui.SetWindowSizeStr
    // ui_show_about_window                                       :: imgui.ShowAboutWindow
    ui_show_demo_window                                        :: imgui.ShowDemoWindow
    // ui_show_font_selector                                      :: imgui.ShowFontSelector
    // ui_show_metrics_window                                     :: imgui.ShowMetricsWindow
    // ui_show_style_editor                                       :: imgui.ShowStyleEditor
    // ui_show_style_selector                                     :: imgui.ShowStyleSelector
    // ui_show_user_guide                                         :: imgui.ShowUserGuide
    // ui_slider_angle                                            :: imgui.SliderAngle
    ui_slider_float                                            :: imgui.SliderFloat
    ui_slider_float2                                           :: imgui.SliderFloat2
    ui_slider_float3                                           :: imgui.SliderFloat3
    ui_slider_float4                                           :: imgui.SliderFloat4
    ui_slider_float_ex                                            :: imgui.SliderFloatEx
    ui_slider_float2_ex                                           :: imgui.SliderFloat2Ex
    ui_slider_float3_ex                                           :: imgui.SliderFloat3Ex
    ui_slider_float4_ex                                           :: imgui.SliderFloat4Ex
    // ui_slider_int                                              :: imgui.SliderInt
    ui_slider_int2                                             :: imgui.SliderInt2
    ui_slider_int3                                             :: imgui.SliderInt3
    ui_slider_int4                                             :: imgui.SliderInt4
    // ui_slider_scalar                                           :: imgui.SliderScalar
    // ui_slider_scalar_n                                         :: imgui.SliderScalarN
    // ui_small_button                                            :: imgui.SmallButton
    // ui_spacing                                                 :: imgui.Spacing
    // ui_style_colors_classic                                    :: imgui.StyleColorsClassic
    // ui_style_colors_dark                                       :: imgui.StyleColorsDark
    // ui_style_colors_light                                      :: imgui.StyleColorsLight
    // ui_tab_item_button                                         :: imgui.TabItemButton
    // ui_table_get_column_count                                  :: imgui.TableGetColumnCount
    // ui_table_get_column_flags                                  :: imgui.TableGetColumnFlags
    // ui_table_get_column_index                                  :: imgui.TableGetColumnIndex
    // ui_table_get_column_name_int                               :: imgui.TableGetColumnNameInt
    // ui_table_get_row_index                                     :: imgui.TableGetRowIndex
    // ui_table_get_sort_specs                                    :: imgui.TableGetSortSpecs
    // ui_table_header                                            :: imgui.TableHeader
    // ui_table_headers_row                                       :: imgui.TableHeadersRow
    // ui_table_next_column                                       :: imgui.TableNextColumn
    ui_table_next_row                                          :: imgui.TableNextRow
    // ui_table_set_bg_color                                      :: imgui.TableSetBgColor
    ui_table_set_column_index                                  :: imgui.TableSetColumnIndex
    // ui_table_setup_column                                      :: imgui.TableSetupColumn
    // ui_table_setup_scroll_freeze                               :: imgui.TableSetupScrollFreeze
    ui_text                                                    :: imgui.Text
    // ui_text_colored                                            :: imgui.TextColored
    // ui_text_disabled                                           :: imgui.TextDisabled
    // ui_text_unformatted                                        :: imgui.TextUnformatted
    // ui_text_wrapped                                            :: imgui.TextWrapped
    // ui_tree_node_str                                           :: imgui.TreeNodeStr
    // ui_tree_node_str_str                                       :: imgui.TreeNodeStrStr
    // ui_tree_node_ptr                                           :: imgui.TreeNodePtr
    // ui_tree_node_ex_str                                        :: imgui.TreeNodeExStr
    // ui_tree_node_ex_str_str                                    :: imgui.TreeNodeExStrStr
    // ui_tree_node_ex_ptr                                        :: imgui.TreeNodeExPtr
    ui_tree_pop                                                :: imgui.TreePop
    // ui_tree_push_str                                           :: imgui.TreePushStr
    // ui_tree_push_ptr                                           :: imgui.TreePushPtr
    // ui_unindent                                                :: imgui.Unindent
    // ui_v_slider_float                                          :: imgui.VSliderFloat
    // ui_v_slider_int                                            :: imgui.VSliderInt
    // ui_v_slider_scalar                                         :: imgui.VSliderScalar
    // ui_value_bool                                              :: imgui.ValueBool
    // ui_value_int                                               :: imgui.ValueInt
    // ui_value_uint                                              :: imgui.ValueUint
    // ui_value_float                                             :: imgui.ValueFloat
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

    Window_Flags :: bit_set[Window_Flag; c.int]
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

    ui_begin :: proc(name: cstring, p_open : ^bool = nil, flags : Window_Flags = {}) -> bool { return false }
    ui_begin_child :: proc {
        ui_begin_child_str,
        ui_begin_child_id,
    }
    ui_begin_child_str :: proc(str_id: cstring, size := Vec2(Vec2 {0,0}), border := bool(false), flags : Window_Flags = {}) -> bool { return false }
    ui_begin_child_id :: proc(id: ImID, size := Vec2(Vec2 {0,0}), border := bool(false), flags : Window_Flags = {}) -> bool { return false }

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
