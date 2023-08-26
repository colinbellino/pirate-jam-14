package engine

import "core:fmt"
import "core:time"

import imgui "../odin-imgui"

UI_Notification :: struct {
    start:    time.Time,
    duration: time.Duration,
    text:     string,
}

ui_create_notification :: proc(text: string, duration: time.Duration = time.Second) {
    _r.debug_notification.start = time.now()
    _r.debug_notification.duration = duration
    _r.debug_notification.text = text
}

ui_debug_window_notification :: proc() {
    if _r.debug_notification.start._nsec > 0 {
        if time.since(_r.debug_notification.start) > _r.debug_notification.duration {
            _r.debug_notification = {}
        } else {
            if ui_window("Notification", nil, .NoResize | .NoMove) {
                ui_set_window_pos_vec2({ _r.rendering_size.x / _r.pixel_density - 200, _r.rendering_size.y / _r.pixel_density - 100 }, .Always)
                ui_text(_r.debug_notification.text)
            }
        }
    }
}

Statistic_Plot :: struct {
    values: [500]f32,
    i:      int,
    stat:   Statistic,
}

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
    ui_plot_lines_float_ptr("", &plot.values[0], len(plot.values), 0, overlay, f32(plot.stat.min), f32(plot.stat.max), { 0, 80 })
}

ui_debug_window_demo :: proc(open: ^bool) {
    when IMGUI_ENABLE {
        imgui.show_demo_window(open)
    }
}

@(deferred_out=_ui_end_menu)
ui_menu :: proc(label: string, enabled := bool(true)) -> bool {
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
ui_tree_node :: proc(label: string, flags := Tree_Node_Flags(0)) -> bool {
    return ui_tree_node_ex(label, flags)
}
_ui_end_tree_node :: proc(open: bool) {
    if open {
        ui_tree_pop()
    }
}

@(deferred_out=_ui_end)
ui_window :: proc(name: string, p_open : ^bool = nil, flags := Window_Flags(0)) -> bool {
    return ui_begin(name, p_open, flags)
}
_ui_end :: proc(collapsed: bool) {
    ui_end()
}


UI_Style                                                   :: imgui.Style
UI_Color                                                   :: imgui.Col
UI_Vec2                                                    :: imgui.Vec2
UI_Vec4                                                    :: imgui.Vec4
Tree_Node_Flags                                            :: imgui.Tree_Node_Flags
Window_Flags                                               :: imgui.Window_Flags

ui_add_text                                                :: imgui.add_text
ui_begin_child                                             :: imgui.begin_child
ui_checkbox_flags                                          :: imgui.checkbox_flags
// ui_collapsing_header                                       :: imgui.collapsing_header
ui_collapsing_header                                       :: imgui.collapsing_header_tree_node_flags
ui_combo                                                   :: imgui.combo
ui_get_background_draw_list                                :: imgui.get_background_draw_list
ui_get_color_u32                                           :: imgui.get_color_u32
ui_get_foreground_draw_list                                :: imgui.get_foreground_draw_list
ui_get_id                                                  :: imgui.get_id
ui_is_popup_open                                           :: imgui.is_popup_open
ui_is_rect_visible                                         :: imgui.is_rect_visible
ui_list_box                                                :: imgui.list_box
ui_menu_item                                               :: imgui.menu_item
ui_plot_histogram                                          :: imgui.plot_histogram
ui_plot_lines                                              :: imgui.plot_lines
ui_push_id                                                 :: imgui.push_id
ui_push_style_color                                        :: imgui.push_style_color
ui_push_style_var                                          :: imgui.push_style_var
ui_radio_button                                            :: imgui.radio_button
ui_selectable                                              :: imgui.selectable
ui_set_scroll_from_pos_x                                   :: imgui.set_scroll_from_pos_x
ui_set_scroll_from_pos_y                                   :: imgui.set_scroll_from_pos_y
ui_set_scroll_x                                            :: imgui.set_scroll_x
ui_set_scroll_y                                            :: imgui.set_scroll_y
ui_set_window_collapsed                                    :: imgui.set_window_collapsed
ui_set_window_focus                                        :: imgui.set_window_focus
ui_set_window_pos                                          :: imgui.set_window_pos
ui_set_window_size                                         :: imgui.set_window_size
ui_table_get_column_name                                   :: imgui.table_get_column_name
// ui_tree_node                                               :: imgui.tree_node
ui_tree_node_ex                                            :: imgui.tree_node_ex
ui_tree_push                                               :: imgui.tree_push
ui_value                                                   :: imgui.value
ui_color_hsv                                               :: imgui.color_hsv
ui_color_set_hsv                                           :: imgui.color_set_hsv
ui_draw_data_clear                                         :: imgui.draw_data_clear
ui_draw_data_de_index_all_buffers                          :: imgui.draw_data_de_index_all_buffers
ui_draw_data_scale_clip_rects                              :: imgui.draw_data_scale_clip_rects
ui_draw_list_splitter_clear                                :: imgui.draw_list_splitter_clear
ui_draw_list_splitter_clear_free_memory                    :: imgui.draw_list_splitter_clear_free_memory
ui_draw_list_splitter_merge                                :: imgui.draw_list_splitter_merge
ui_draw_list_splitter_set_current_channel                  :: imgui.draw_list_splitter_set_current_channel
ui_draw_list_splitter_split                                :: imgui.draw_list_splitter_split
ui_draw_list_add_bezier_cubic                              :: imgui.draw_list_add_bezier_cubic
ui_draw_list_add_bezier_quadratic                          :: imgui.draw_list_add_bezier_quadratic
ui_draw_list_add_callback                                  :: imgui.draw_list_add_callback
ui_draw_list_add_circle                                    :: imgui.draw_list_add_circle
ui_draw_list_add_circle_filled                             :: imgui.draw_list_add_circle_filled
ui_draw_list_add_convex_poly_filled                        :: imgui.draw_list_add_convex_poly_filled
ui_draw_list_add_draw_cmd                                  :: imgui.draw_list_add_draw_cmd
ui_draw_list_add_image                                     :: imgui.draw_list_add_image
ui_draw_list_add_image_quad                                :: imgui.draw_list_add_image_quad
ui_draw_list_add_image_rounded                             :: imgui.draw_list_add_image_rounded
ui_draw_list_add_line                                      :: imgui.draw_list_add_line
ui_draw_list_add_ngon                                      :: imgui.draw_list_add_ngon
ui_draw_list_add_ngon_filled                               :: imgui.draw_list_add_ngon_filled
ui_draw_list_add_polyline                                  :: imgui.draw_list_add_polyline
ui_draw_list_add_quad                                      :: imgui.draw_list_add_quad
ui_draw_list_add_quad_filled                               :: imgui.draw_list_add_quad_filled
ui_draw_list_add_rect                                      :: imgui.draw_list_add_rect
ui_draw_list_add_rect_filled                               :: imgui.draw_list_add_rect_filled
ui_draw_list_add_rect_filled_multi_color                   :: imgui.draw_list_add_rect_filled_multi_color
ui_draw_list_add_text_vec2                                 :: imgui.draw_list_add_text_vec2
ui_draw_list_add_text_font_ptr                             :: imgui.draw_list_add_text_font_ptr
ui_draw_list_add_triangle                                  :: imgui.draw_list_add_triangle
ui_draw_list_add_triangle_filled                           :: imgui.draw_list_add_triangle_filled
ui_draw_list_channels_merge                                :: imgui.draw_list_channels_merge
ui_draw_list_channels_set_current                          :: imgui.draw_list_channels_set_current
ui_draw_list_channels_split                                :: imgui.draw_list_channels_split
ui_draw_list_clone_output                                  :: imgui.draw_list_clone_output
ui_draw_list_get_clip_rect_max                             :: imgui.draw_list_get_clip_rect_max
ui_draw_list_get_clip_rect_min                             :: imgui.draw_list_get_clip_rect_min
ui_draw_list_path_arc_to                                   :: imgui.draw_list_path_arc_to
ui_draw_list_path_arc_to_fast                              :: imgui.draw_list_path_arc_to_fast
ui_draw_list_path_bezier_cubic_curve_to                    :: imgui.draw_list_path_bezier_cubic_curve_to
ui_draw_list_path_bezier_quadratic_curve_to                :: imgui.draw_list_path_bezier_quadratic_curve_to
ui_draw_list_path_clear                                    :: imgui.draw_list_path_clear
ui_draw_list_path_fill_convex                              :: imgui.draw_list_path_fill_convex
ui_draw_list_path_line_to                                  :: imgui.draw_list_path_line_to
ui_draw_list_path_line_to_merge_duplicate                  :: imgui.draw_list_path_line_to_merge_duplicate
ui_draw_list_path_rect                                     :: imgui.draw_list_path_rect
ui_draw_list_path_stroke                                   :: imgui.draw_list_path_stroke
ui_draw_list_pop_clip_rect                                 :: imgui.draw_list_pop_clip_rect
ui_draw_list_pop_texture_id                                :: imgui.draw_list_pop_texture_id
ui_draw_list_prim_quad_uv                                  :: imgui.draw_list_prim_quad_uv
ui_draw_list_prim_rect                                     :: imgui.draw_list_prim_rect
ui_draw_list_prim_rect_uv                                  :: imgui.draw_list_prim_rect_uv
ui_draw_list_prim_reserve                                  :: imgui.draw_list_prim_reserve
ui_draw_list_prim_unreserve                                :: imgui.draw_list_prim_unreserve
ui_draw_list_prim_vtx                                      :: imgui.draw_list_prim_vtx
ui_draw_list_prim_write_idx                                :: imgui.draw_list_prim_write_idx
ui_draw_list_prim_write_vtx                                :: imgui.draw_list_prim_write_vtx
ui_draw_list_push_clip_rect                                :: imgui.draw_list_push_clip_rect
ui_draw_list_push_clip_rect_full_screen                    :: imgui.draw_list_push_clip_rect_full_screen
ui_draw_list_push_texture_id                               :: imgui.draw_list_push_texture_id
ui_draw_list_calc_circle_auto_segment_count                :: imgui.draw_list_calc_circle_auto_segment_count
ui_draw_list_clear_free_memory                             :: imgui.draw_list_clear_free_memory
ui_draw_list_on_changed_clip_rect                          :: imgui.draw_list_on_changed_clip_rect
ui_draw_list_on_changed_texture_id                         :: imgui.draw_list_on_changed_texture_id
ui_draw_list_on_changed_vtx_offset                         :: imgui.draw_list_on_changed_vtx_offset
ui_draw_list_path_arc_to_fast_ex                           :: imgui.draw_list_path_arc_to_fast_ex
ui_draw_list_path_arc_to_n                                 :: imgui.draw_list_path_arc_to_n
ui_draw_list_pop_unused_draw_cmd                           :: imgui.draw_list_pop_unused_draw_cmd
ui_draw_list_reset_for_new_frame                           :: imgui.draw_list_reset_for_new_frame
ui_font_atlas_custom_rect_is_packed                        :: imgui.font_atlas_custom_rect_is_packed
ui_font_atlas_add_custom_rect_font_glyph                   :: imgui.font_atlas_add_custom_rect_font_glyph
ui_font_atlas_add_custom_rect_regular                      :: imgui.font_atlas_add_custom_rect_regular
ui_font_atlas_add_font                                     :: imgui.font_atlas_add_font
ui_font_atlas_add_font_default                             :: imgui.font_atlas_add_font_default
ui_font_atlas_add_font_from_file_ttf                       :: imgui.font_atlas_add_font_from_file_ttf
ui_font_atlas_add_font_from_memory_compressed_base85ttf    :: imgui.font_atlas_add_font_from_memory_compressed_base85ttf
ui_font_atlas_add_font_from_memory_compressed_ttf          :: imgui.font_atlas_add_font_from_memory_compressed_ttf
ui_font_atlas_add_font_from_memory_ttf                     :: imgui.font_atlas_add_font_from_memory_ttf
ui_font_atlas_build                                        :: imgui.font_atlas_build
ui_font_atlas_calc_custom_rect_uv                          :: imgui.font_atlas_calc_custom_rect_uv
ui_font_atlas_clear                                        :: imgui.font_atlas_clear
ui_font_atlas_clear_fonts                                  :: imgui.font_atlas_clear_fonts
ui_font_atlas_clear_input_data                             :: imgui.font_atlas_clear_input_data
ui_font_atlas_clear_tex_data                               :: imgui.font_atlas_clear_tex_data
ui_font_atlas_get_custom_rect_by_index                     :: imgui.font_atlas_get_custom_rect_by_index
ui_font_atlas_get_glyph_ranges_chinese_full                :: imgui.font_atlas_get_glyph_ranges_chinese_full
ui_font_atlas_get_glyph_ranges_chinese_simplified_common   :: imgui.font_atlas_get_glyph_ranges_chinese_simplified_common
ui_font_atlas_get_glyph_ranges_cyrillic                    :: imgui.font_atlas_get_glyph_ranges_cyrillic
ui_font_atlas_get_glyph_ranges_default                     :: imgui.font_atlas_get_glyph_ranges_default
ui_font_atlas_get_glyph_ranges_japanese                    :: imgui.font_atlas_get_glyph_ranges_japanese
ui_font_atlas_get_glyph_ranges_korean                      :: imgui.font_atlas_get_glyph_ranges_korean
ui_font_atlas_get_glyph_ranges_thai                        :: imgui.font_atlas_get_glyph_ranges_thai
ui_font_atlas_get_glyph_ranges_vietnamese                  :: imgui.font_atlas_get_glyph_ranges_vietnamese
ui_font_atlas_get_mouse_cursor_tex_data                    :: imgui.font_atlas_get_mouse_cursor_tex_data
ui_font_atlas_get_tex_data_as_alpha8                       :: imgui.font_atlas_get_tex_data_as_alpha8
ui_font_atlas_get_tex_data_as_rgba32                       :: imgui.font_atlas_get_tex_data_as_rgba32
ui_font_atlas_is_built                                     :: imgui.font_atlas_is_built
ui_font_atlas_set_tex_id                                   :: imgui.font_atlas_set_tex_id
ui_font_glyph_ranges_builder_add_char                      :: imgui.font_glyph_ranges_builder_add_char
ui_font_glyph_ranges_builder_add_ranges                    :: imgui.font_glyph_ranges_builder_add_ranges
ui_font_glyph_ranges_builder_add_text                      :: imgui.font_glyph_ranges_builder_add_text
ui_font_glyph_ranges_builder_build_ranges                  :: imgui.font_glyph_ranges_builder_build_ranges
ui_font_glyph_ranges_builder_clear                         :: imgui.font_glyph_ranges_builder_clear
ui_font_glyph_ranges_builder_get_bit                       :: imgui.font_glyph_ranges_builder_get_bit
ui_font_glyph_ranges_builder_set_bit                       :: imgui.font_glyph_ranges_builder_set_bit
ui_font_add_glyph                                          :: imgui.font_add_glyph
ui_font_add_remap_char                                     :: imgui.font_add_remap_char
ui_font_build_lookup_table                                 :: imgui.font_build_lookup_table
ui_font_calc_text_size_a                                   :: imgui.font_calc_text_size_a
ui_font_calc_word_wrap_position_a                          :: imgui.font_calc_word_wrap_position_a
ui_font_clear_output_data                                  :: imgui.font_clear_output_data
ui_font_find_glyph                                         :: imgui.font_find_glyph
ui_font_find_glyph_no_fallback                             :: imgui.font_find_glyph_no_fallback
ui_font_get_char_advance                                   :: imgui.font_get_char_advance
ui_font_get_debug_name                                     :: imgui.font_get_debug_name
ui_font_grow_index                                         :: imgui.font_grow_index
ui_font_is_glyph_range_unused                              :: imgui.font_is_glyph_range_unused
ui_font_is_loaded                                          :: imgui.font_is_loaded
ui_font_render_char                                        :: imgui.font_render_char
ui_font_render_text                                        :: imgui.font_render_text
ui_font_set_fallback_char                                  :: imgui.font_set_fallback_char
ui_font_set_glyph_visible                                  :: imgui.font_set_glyph_visible
ui_io_add_input_character                                  :: imgui.io_add_input_character
ui_io_add_input_character_utf16                            :: imgui.io_add_input_character_utf16
ui_io_add_input_characters_utf8                            :: imgui.io_add_input_characters_utf8
ui_io_clear_input_characters                               :: imgui.io_clear_input_characters
ui_input_text_callback_data_clear_selection                :: imgui.input_text_callback_data_clear_selection
ui_input_text_callback_data_delete_chars                   :: imgui.input_text_callback_data_delete_chars
ui_input_text_callback_data_has_selection                  :: imgui.input_text_callback_data_has_selection
ui_input_text_callback_data_insert_chars                   :: imgui.input_text_callback_data_insert_chars
ui_input_text_callback_data_select_all                     :: imgui.input_text_callback_data_select_all
ui_list_clipper_begin                                      :: imgui.list_clipper_begin
ui_list_clipper_end                                        :: imgui.list_clipper_end
ui_list_clipper_step                                       :: imgui.list_clipper_step
ui_payload_clear                                           :: imgui.payload_clear
ui_payload_is_data_type                                    :: imgui.payload_is_data_type
ui_payload_is_delivery                                     :: imgui.payload_is_delivery
ui_payload_is_preview                                      :: imgui.payload_is_preview
ui_storage_build_sort_by_key                               :: imgui.storage_build_sort_by_key
ui_storage_clear                                           :: imgui.storage_clear
ui_storage_get_bool                                        :: imgui.storage_get_bool
ui_storage_get_bool_ref                                    :: imgui.storage_get_bool_ref
ui_storage_get_float                                       :: imgui.storage_get_float
ui_storage_get_float_ref                                   :: imgui.storage_get_float_ref
ui_storage_get_int                                         :: imgui.storage_get_int
ui_storage_get_int_ref                                     :: imgui.storage_get_int_ref
ui_storage_get_void_ptr                                    :: imgui.storage_get_void_ptr
ui_storage_get_void_ptr_ref                                :: imgui.storage_get_void_ptr_ref
ui_storage_set_all_int                                     :: imgui.storage_set_all_int
ui_storage_set_bool                                        :: imgui.storage_set_bool
ui_storage_set_float                                       :: imgui.storage_set_float
ui_storage_set_int                                         :: imgui.storage_set_int
ui_storage_set_void_ptr                                    :: imgui.storage_set_void_ptr
ui_style_scale_all_sizes                                   :: imgui.style_scale_all_sizes
ui_text_buffer_append                                      :: imgui.text_buffer_append
ui_text_buffer_appendf                                     :: imgui.text_buffer_appendf
ui_text_buffer_begin                                       :: imgui.text_buffer_begin
ui_text_buffer_c_str                                       :: imgui.text_buffer_c_str
ui_text_buffer_clear                                       :: imgui.text_buffer_clear
ui_text_buffer_empty                                       :: imgui.text_buffer_empty
ui_text_buffer_end                                         :: imgui.text_buffer_end
ui_text_buffer_reserve                                     :: imgui.text_buffer_reserve
ui_text_buffer_size                                        :: imgui.text_buffer_size
ui_text_filter_build                                       :: imgui.text_filter_build
ui_text_filter_clear                                       :: imgui.text_filter_clear
ui_text_filter_draw                                        :: imgui.text_filter_draw
ui_text_filter_is_active                                   :: imgui.text_filter_is_active
ui_text_filter_pass_filter                                 :: imgui.text_filter_pass_filter
ui_text_range_empty                                        :: imgui.text_range_empty
ui_text_range_split                                        :: imgui.text_range_split
ui_viewport_get_center                                     :: imgui.viewport_get_center
ui_viewport_get_work_center                                :: imgui.viewport_get_work_center
ui_accept_drag_drop_payload                                :: imgui.accept_drag_drop_payload
ui_align_text_to_frame_padding                             :: imgui.align_text_to_frame_padding
ui_arrow_button                                            :: imgui.arrow_button
ui_begin                                                   :: imgui.begin
ui_begin_child_str                                         :: imgui.begin_child_str
ui_begin_child_id                                          :: imgui.begin_child_id
ui_begin_child_frame                                       :: imgui.begin_child_frame
ui_begin_combo                                             :: imgui.begin_combo
ui_begin_drag_drop_source                                  :: imgui.begin_drag_drop_source
ui_begin_drag_drop_target                                  :: imgui.begin_drag_drop_target
ui_begin_group                                             :: imgui.begin_group
ui_begin_list_box                                          :: imgui.begin_list_box
ui_begin_main_menu_bar                                     :: imgui.begin_main_menu_bar
ui_begin_menu                                              :: imgui.begin_menu
ui_begin_menu_bar                                          :: imgui.begin_menu_bar
ui_begin_popup                                             :: imgui.begin_popup
ui_begin_popup_context_item                                :: imgui.begin_popup_context_item
ui_begin_popup_context_void                                :: imgui.begin_popup_context_void
ui_begin_popup_context_window                              :: imgui.begin_popup_context_window
ui_begin_popup_modal                                       :: imgui.begin_popup_modal
ui_begin_tab_bar                                           :: imgui.begin_tab_bar
ui_begin_tab_item                                          :: imgui.begin_tab_item
ui_begin_table                                             :: imgui.begin_table
ui_begin_tooltip                                           :: imgui.begin_tooltip
ui_bullet                                                  :: imgui.bullet
ui_bullet_text                                             :: imgui.bullet_text
ui_button                                                  :: imgui.button
ui_calc_item_width                                         :: imgui.calc_item_width
ui_calc_list_clipping                                      :: imgui.calc_list_clipping
ui_calc_text_size                                          :: imgui.calc_text_size
ui_capture_keyboard_from_app                               :: imgui.capture_keyboard_from_app
ui_capture_mouse_from_app                                  :: imgui.capture_mouse_from_app
ui_checkbox                                                :: imgui.checkbox
ui_checkbox_flags_int_ptr                                  :: imgui.checkbox_flags_int_ptr
ui_checkbox_flags_uint_ptr                                 :: imgui.checkbox_flags_uint_ptr
ui_close_current_popup                                     :: imgui.close_current_popup
ui_collapsing_header_tree_node_flags                       :: imgui.collapsing_header_tree_node_flags
ui_collapsing_header_bool_ptr                              :: imgui.collapsing_header_bool_ptr
ui_color_button                                            :: imgui.color_button
ui_color_convert_float4to_u32                              :: imgui.color_convert_float4to_u32
ui_color_convert_hs_vto_rgb                                :: imgui.color_convert_hs_vto_rgb
ui_color_convert_rg_bto_hsv                                :: imgui.color_convert_rg_bto_hsv
ui_color_convert_u32to_float4                              :: imgui.color_convert_u32to_float4
ui_color_edit3                                             :: imgui.color_edit3
ui_color_edit4                                             :: imgui.color_edit4
ui_color_picker3                                           :: imgui.color_picker3
ui_color_picker4                                           :: imgui.color_picker4
ui_columns                                                 :: imgui.columns
ui_combo_str_arr                                           :: imgui.combo_str_arr
ui_combo_str                                               :: imgui.combo_str
ui_combo_fn_bool_ptr                                       :: imgui.combo_fn_bool_ptr
ui_create_context                                          :: imgui.create_context
ui_debug_check_version_and_data_layout                     :: imgui.debug_check_version_and_data_layout
ui_destroy_context                                         :: imgui.destroy_context
ui_drag_float                                              :: imgui.drag_float
ui_drag_float2                                             :: imgui.drag_float2
ui_drag_float3                                             :: imgui.drag_float3
ui_drag_float4                                             :: imgui.drag_float4
ui_drag_float_range2                                       :: imgui.drag_float_range2
ui_drag_int                                                :: imgui.drag_int
ui_drag_int2                                               :: imgui.drag_int2
ui_drag_int3                                               :: imgui.drag_int3
ui_drag_int4                                               :: imgui.drag_int4
ui_drag_int_range2                                         :: imgui.drag_int_range2
ui_drag_scalar                                             :: imgui.drag_scalar
ui_drag_scalar_n                                           :: imgui.drag_scalar_n
ui_dummy                                                   :: imgui.dummy
ui_end                                                     :: imgui.end
ui_end_child                                               :: imgui.end_child
ui_end_child_frame                                         :: imgui.end_child_frame
ui_end_combo                                               :: imgui.end_combo
ui_end_drag_drop_source                                    :: imgui.end_drag_drop_source
ui_end_drag_drop_target                                    :: imgui.end_drag_drop_target
ui_end_frame                                               :: imgui.end_frame
ui_end_group                                               :: imgui.end_group
ui_end_list_box                                            :: imgui.end_list_box
ui_end_main_menu_bar                                       :: imgui.end_main_menu_bar
ui_end_menu                                                :: imgui.end_menu
ui_end_menu_bar                                            :: imgui.end_menu_bar
ui_end_popup                                               :: imgui.end_popup
ui_end_tab_bar                                             :: imgui.end_tab_bar
ui_end_tab_item                                            :: imgui.end_tab_item
ui_end_table                                               :: imgui.end_table
ui_end_tooltip                                             :: imgui.end_tooltip
ui_get_allocator_functions                                 :: imgui.get_allocator_functions
ui_get_background_draw_list_nil                            :: imgui.get_background_draw_list_nil
ui_get_clipboard_text                                      :: imgui.get_clipboard_text
ui_get_color_u32_col                                       :: imgui.get_color_u32_col
ui_get_color_u32_vec4                                      :: imgui.get_color_u32_vec4
ui_get_color_u32_u32                                       :: imgui.get_color_u32_u32
ui_get_column_index                                        :: imgui.get_column_index
ui_get_column_offset                                       :: imgui.get_column_offset
ui_get_column_width                                        :: imgui.get_column_width
ui_get_columns_count                                       :: imgui.get_columns_count
ui_get_content_region_avail                                :: imgui.get_content_region_avail
ui_get_content_region_max                                  :: imgui.get_content_region_max
ui_get_current_context                                     :: imgui.get_current_context
ui_get_cursor_pos                                          :: imgui.get_cursor_pos
ui_get_cursor_pos_x                                        :: imgui.get_cursor_pos_x
ui_get_cursor_pos_y                                        :: imgui.get_cursor_pos_y
ui_get_cursor_screen_pos                                   :: imgui.get_cursor_screen_pos
ui_get_cursor_start_pos                                    :: imgui.get_cursor_start_pos
ui_get_drag_drop_payload                                   :: imgui.get_drag_drop_payload
ui_get_draw_data                                           :: imgui.get_draw_data
ui_get_draw_list_shared_data                               :: imgui.get_draw_list_shared_data
ui_get_font                                                :: imgui.get_font
ui_get_font_size                                           :: imgui.get_font_size
ui_get_font_tex_uv_white_pixel                             :: imgui.get_font_tex_uv_white_pixel
ui_get_foreground_draw_list_nil                            :: imgui.get_foreground_draw_list_nil
ui_get_frame_count                                         :: imgui.get_frame_count
ui_get_frame_height                                        :: imgui.get_frame_height
ui_get_frame_height_with_spacing                           :: imgui.get_frame_height_with_spacing
ui_get_id_str                                              :: imgui.get_id_str
ui_get_id_str_str                                          :: imgui.get_id_str_str
ui_get_id_ptr                                              :: imgui.get_id_ptr
ui_get_io                                                  :: imgui.get_io
ui_get_item_rect_max                                       :: imgui.get_item_rect_max
ui_get_item_rect_min                                       :: imgui.get_item_rect_min
ui_get_item_rect_size                                      :: imgui.get_item_rect_size
ui_get_key_index                                           :: imgui.get_key_index
ui_get_key_pressed_amount                                  :: imgui.get_key_pressed_amount
ui_get_main_viewport                                       :: imgui.get_main_viewport
ui_get_mouse_cursor                                        :: imgui.get_mouse_cursor
ui_get_mouse_drag_delta                                    :: imgui.get_mouse_drag_delta
ui_get_mouse_pos                                           :: imgui.get_mouse_pos
ui_get_mouse_pos_on_opening_current_popup                  :: imgui.get_mouse_pos_on_opening_current_popup
ui_get_scroll_max_x                                        :: imgui.get_scroll_max_x
ui_get_scroll_max_y                                        :: imgui.get_scroll_max_y
ui_get_scroll_x                                            :: imgui.get_scroll_x
ui_get_scroll_y                                            :: imgui.get_scroll_y
ui_get_state_storage                                       :: imgui.get_state_storage
ui_get_style                                               :: imgui.get_style
ui_get_style_color_name                                    :: imgui.get_style_color_name
ui_get_style_color_vec4                                    :: imgui.get_style_color_vec4
ui_get_text_line_height                                    :: imgui.get_text_line_height
ui_get_text_line_height_with_spacing                       :: imgui.get_text_line_height_with_spacing
ui_get_time                                                :: imgui.get_time
ui_get_tree_node_to_label_spacing                          :: imgui.get_tree_node_to_label_spacing
ui_get_version                                             :: imgui.get_version
ui_get_window_content_region_max                           :: imgui.get_window_content_region_max
ui_get_window_content_region_min                           :: imgui.get_window_content_region_min
ui_get_window_content_region_width                         :: imgui.get_window_content_region_width
ui_get_window_draw_list                                    :: imgui.get_window_draw_list
ui_get_window_height                                       :: imgui.get_window_height
ui_get_window_pos                                          :: imgui.get_window_pos
ui_get_window_size                                         :: imgui.get_window_size
ui_get_window_width                                        :: imgui.get_window_width
ui_image                                                   :: imgui.image
ui_image_button                                            :: imgui.image_button
ui_indent                                                  :: imgui.indent
ui_input_double                                            :: imgui.input_double
ui_input_float                                             :: imgui.input_float
ui_input_float2                                            :: imgui.input_float2
ui_input_float3                                            :: imgui.input_float3
ui_input_float4                                            :: imgui.input_float4
ui_input_int                                               :: imgui.input_int
ui_input_int2                                              :: imgui.input_int2
ui_input_int3                                              :: imgui.input_int3
ui_input_int4                                              :: imgui.input_int4
ui_input_scalar                                            :: imgui.input_scalar
ui_input_scalar_n                                          :: imgui.input_scalar_n
ui_input_text                                              :: imgui.input_text
ui_input_text_multiline                                    :: imgui.input_text_multiline
ui_input_text_with_hint                                    :: imgui.input_text_with_hint
ui_invisible_button                                        :: imgui.invisible_button
ui_is_any_item_active                                      :: imgui.is_any_item_active
ui_is_any_item_focused                                     :: imgui.is_any_item_focused
ui_is_any_item_hovered                                     :: imgui.is_any_item_hovered
ui_is_any_mouse_down                                       :: imgui.is_any_mouse_down
ui_is_item_activated                                       :: imgui.is_item_activated
ui_is_item_active                                          :: imgui.is_item_active
ui_is_item_clicked                                         :: imgui.is_item_clicked
ui_is_item_deactivated                                     :: imgui.is_item_deactivated
ui_is_item_deactivated_after_edit                          :: imgui.is_item_deactivated_after_edit
ui_is_item_edited                                          :: imgui.is_item_edited
ui_is_item_focused                                         :: imgui.is_item_focused
ui_is_item_hovered                                         :: imgui.is_item_hovered
ui_is_item_toggled_open                                    :: imgui.is_item_toggled_open
ui_is_item_visible                                         :: imgui.is_item_visible
ui_is_key_down                                             :: imgui.is_key_down
ui_is_key_pressed                                          :: imgui.is_key_pressed
ui_is_key_released                                         :: imgui.is_key_released
ui_is_mouse_clicked                                        :: imgui.is_mouse_clicked
ui_is_mouse_double_clicked                                 :: imgui.is_mouse_double_clicked
ui_is_mouse_down                                           :: imgui.is_mouse_down
ui_is_mouse_dragging                                       :: imgui.is_mouse_dragging
ui_is_mouse_hovering_rect                                  :: imgui.is_mouse_hovering_rect
ui_is_mouse_pos_valid                                      :: imgui.is_mouse_pos_valid
ui_is_mouse_released                                       :: imgui.is_mouse_released
ui_is_popup_open_str                                       :: imgui.is_popup_open_str
ui_is_rect_visible_nil                                     :: imgui.is_rect_visible_nil
ui_is_rect_visible_vec2                                    :: imgui.is_rect_visible_vec2
ui_is_window_appearing                                     :: imgui.is_window_appearing
ui_is_window_collapsed                                     :: imgui.is_window_collapsed
ui_is_window_focused                                       :: imgui.is_window_focused
ui_is_window_hovered                                       :: imgui.is_window_hovered
ui_label_text                                              :: imgui.label_text
ui_list_box_str_arr                                        :: imgui.list_box_str_arr
ui_list_box_fn_bool_ptr                                    :: imgui.list_box_fn_bool_ptr
ui_load_ini_settings_from_disk                             :: imgui.load_ini_settings_from_disk
ui_load_ini_settings_from_memory                           :: imgui.load_ini_settings_from_memory
ui_log_buttons                                             :: imgui.log_buttons
ui_log_finish                                              :: imgui.log_finish
ui_log_text                                                :: imgui.log_text
ui_log_to_clipboard                                        :: imgui.log_to_clipboard
ui_log_to_file                                             :: imgui.log_to_file
ui_log_to_tty                                              :: imgui.log_to_tty
ui_mem_alloc                                               :: imgui.mem_alloc
ui_mem_free                                                :: imgui.mem_free
ui_menu_item_bool                                          :: imgui.menu_item_bool
ui_menu_item_bool_ptr                                      :: imgui.menu_item_bool_ptr
ui_new_frame                                               :: imgui.new_frame
ui_new_line                                                :: imgui.new_line
ui_next_column                                             :: imgui.next_column
ui_open_popup                                              :: imgui.open_popup
ui_open_popup_on_item_click                                :: imgui.open_popup_on_item_click
ui_plot_histogram_float_ptr                                :: imgui.plot_histogram_float_ptr
ui_plot_histogram_fn_float_ptr                             :: imgui.plot_histogram_fn_float_ptr
ui_plot_lines_float_ptr                                    :: imgui.plot_lines_float_ptr
ui_plot_lines_fn_float_ptr                                 :: imgui.plot_lines_fn_float_ptr
ui_pop_allow_keyboard_focus                                :: imgui.pop_allow_keyboard_focus
ui_pop_button_repeat                                       :: imgui.pop_button_repeat
ui_pop_clip_rect                                           :: imgui.pop_clip_rect
ui_pop_font                                                :: imgui.pop_font
ui_pop_id                                                  :: imgui.pop_id
ui_pop_item_width                                          :: imgui.pop_item_width
ui_pop_style_color                                         :: imgui.pop_style_color
ui_pop_style_var                                           :: imgui.pop_style_var
ui_pop_text_wrap_pos                                       :: imgui.pop_text_wrap_pos
ui_progress_bar                                            :: imgui.progress_bar
ui_push_allow_keyboard_focus                               :: imgui.push_allow_keyboard_focus
ui_push_button_repeat                                      :: imgui.push_button_repeat
ui_push_clip_rect                                          :: imgui.push_clip_rect
ui_push_font                                               :: imgui.push_font
ui_push_id_str                                             :: imgui.push_id_str
ui_push_id_str_str                                         :: imgui.push_id_str_str
ui_push_id_ptr                                             :: imgui.push_id_ptr
ui_push_id_int                                             :: imgui.push_id_int
ui_push_item_width                                         :: imgui.push_item_width
ui_push_style_color_u32                                    :: imgui.push_style_color_u32
ui_push_style_color_vec4                                   :: imgui.push_style_color_vec4
ui_push_style_var_float                                    :: imgui.push_style_var_float
ui_push_style_var_vec2                                     :: imgui.push_style_var_vec2
ui_push_text_wrap_pos                                      :: imgui.push_text_wrap_pos
ui_radio_button_bool                                       :: imgui.radio_button_bool
ui_radio_button_int_ptr                                    :: imgui.radio_button_int_ptr
ui_render                                                  :: imgui.render
ui_reset_mouse_drag_delta                                  :: imgui.reset_mouse_drag_delta
ui_same_line                                               :: imgui.same_line
ui_save_ini_settings_to_disk                               :: imgui.save_ini_settings_to_disk
ui_save_ini_settings_to_memory                             :: imgui.save_ini_settings_to_memory
ui_selectable_bool                                         :: imgui.selectable_bool
ui_selectable_bool_ptr                                     :: imgui.selectable_bool_ptr
ui_separator                                               :: imgui.separator
ui_set_allocator_functions                                 :: imgui.set_allocator_functions
ui_set_clipboard_text                                      :: imgui.set_clipboard_text
ui_set_color_edit_options                                  :: imgui.set_color_edit_options
ui_set_column_offset                                       :: imgui.set_column_offset
ui_set_column_width                                        :: imgui.set_column_width
ui_set_current_context                                     :: imgui.set_current_context
ui_set_cursor_pos                                          :: imgui.set_cursor_pos
ui_set_cursor_pos_x                                        :: imgui.set_cursor_pos_x
ui_set_cursor_pos_y                                        :: imgui.set_cursor_pos_y
ui_set_cursor_screen_pos                                   :: imgui.set_cursor_screen_pos
ui_set_drag_drop_payload                                   :: imgui.set_drag_drop_payload
ui_set_item_allow_overlap                                  :: imgui.set_item_allow_overlap
ui_set_item_default_focus                                  :: imgui.set_item_default_focus
ui_set_keyboard_focus_here                                 :: imgui.set_keyboard_focus_here
ui_set_mouse_cursor                                        :: imgui.set_mouse_cursor
ui_set_next_item_open                                      :: imgui.set_next_item_open
ui_set_next_item_width                                     :: imgui.set_next_item_width
ui_set_next_window_bg_alpha                                :: imgui.set_next_window_bg_alpha
ui_set_next_window_collapsed                               :: imgui.set_next_window_collapsed
ui_set_next_window_content_size                            :: imgui.set_next_window_content_size
ui_set_next_window_focus                                   :: imgui.set_next_window_focus
ui_set_next_window_pos                                     :: imgui.set_next_window_pos
ui_set_next_window_size                                    :: imgui.set_next_window_size
ui_set_next_window_size_constraints                        :: imgui.set_next_window_size_constraints
ui_set_scroll_from_pos_x_float                             :: imgui.set_scroll_from_pos_x_float
ui_set_scroll_from_pos_y_float                             :: imgui.set_scroll_from_pos_y_float
ui_set_scroll_here_x                                       :: imgui.set_scroll_here_x
ui_set_scroll_here_y                                       :: imgui.set_scroll_here_y
ui_set_scroll_x_float                                      :: imgui.set_scroll_x_float
ui_set_scroll_y_float                                      :: imgui.set_scroll_y_float
ui_set_state_storage                                       :: imgui.set_state_storage
ui_set_tab_item_closed                                     :: imgui.set_tab_item_closed
ui_set_tooltip                                             :: imgui.set_tooltip
ui_set_window_collapsed_bool                               :: imgui.set_window_collapsed_bool
ui_set_window_collapsed_str                                :: imgui.set_window_collapsed_str
ui_set_window_focus_nil                                    :: imgui.set_window_focus_nil
ui_set_window_focus_str                                    :: imgui.set_window_focus_str
ui_set_window_font_scale                                   :: imgui.set_window_font_scale
ui_set_window_pos_vec2                                     :: imgui.set_window_pos_vec2
ui_set_window_pos_str                                      :: imgui.set_window_pos_str
ui_set_window_size_vec2                                    :: imgui.set_window_size_vec2
ui_set_window_size_str                                     :: imgui.set_window_size_str
ui_show_about_window                                       :: imgui.show_about_window
ui_show_demo_window                                        :: imgui.show_demo_window
ui_show_font_selector                                      :: imgui.show_font_selector
ui_show_metrics_window                                     :: imgui.show_metrics_window
ui_show_style_editor                                       :: imgui.show_style_editor
ui_show_style_selector                                     :: imgui.show_style_selector
ui_show_user_guide                                         :: imgui.show_user_guide
ui_slider_angle                                            :: imgui.slider_angle
ui_slider_float                                            :: imgui.slider_float
ui_slider_float2                                           :: imgui.slider_float2
ui_slider_float3                                           :: imgui.slider_float3
ui_slider_float4                                           :: imgui.slider_float4
ui_slider_int                                              :: imgui.slider_int
ui_slider_int2                                             :: imgui.slider_int2
ui_slider_int3                                             :: imgui.slider_int3
ui_slider_int4                                             :: imgui.slider_int4
ui_slider_scalar                                           :: imgui.slider_scalar
ui_slider_scalar_n                                         :: imgui.slider_scalar_n
ui_small_button                                            :: imgui.small_button
ui_spacing                                                 :: imgui.spacing
ui_style_colors_classic                                    :: imgui.style_colors_classic
ui_style_colors_dark                                       :: imgui.style_colors_dark
ui_style_colors_light                                      :: imgui.style_colors_light
ui_tab_item_button                                         :: imgui.tab_item_button
ui_table_get_column_count                                  :: imgui.table_get_column_count
ui_table_get_column_flags                                  :: imgui.table_get_column_flags
ui_table_get_column_index                                  :: imgui.table_get_column_index
ui_table_get_column_name_int                               :: imgui.table_get_column_name_int
ui_table_get_row_index                                     :: imgui.table_get_row_index
ui_table_get_sort_specs                                    :: imgui.table_get_sort_specs
ui_table_header                                            :: imgui.table_header
ui_table_headers_row                                       :: imgui.table_headers_row
ui_table_next_column                                       :: imgui.table_next_column
ui_table_next_row                                          :: imgui.table_next_row
ui_table_set_bg_color                                      :: imgui.table_set_bg_color
ui_table_set_column_index                                  :: imgui.table_set_column_index
ui_table_setup_column                                      :: imgui.table_setup_column
ui_table_setup_scroll_freeze                               :: imgui.table_setup_scroll_freeze
ui_text                                                    :: imgui.text
ui_text_colored                                            :: imgui.text_colored
ui_text_disabled                                           :: imgui.text_disabled
ui_text_unformatted                                        :: imgui.text_unformatted
ui_text_wrapped                                            :: imgui.text_wrapped
ui_tree_node_str                                           :: imgui.tree_node_str
ui_tree_node_str_str                                       :: imgui.tree_node_str_str
ui_tree_node_ptr                                           :: imgui.tree_node_ptr
ui_tree_node_ex_str                                        :: imgui.tree_node_ex_str
ui_tree_node_ex_str_str                                    :: imgui.tree_node_ex_str_str
ui_tree_node_ex_ptr                                        :: imgui.tree_node_ex_ptr
ui_tree_pop                                                :: imgui.tree_pop
ui_tree_push_str                                           :: imgui.tree_push_str
ui_tree_push_ptr                                           :: imgui.tree_push_ptr
ui_unindent                                                :: imgui.unindent
ui_v_slider_float                                          :: imgui.v_slider_float
ui_v_slider_int                                            :: imgui.v_slider_int
ui_v_slider_scalar                                         :: imgui.v_slider_scalar
ui_value_bool                                              :: imgui.value_bool
ui_value_int                                               :: imgui.value_int
ui_value_uint                                              :: imgui.value_uint
ui_value_float                                             :: imgui.value_float
