package game

import "core:math"
import "core:fmt"
import "core:slice"
import "core:log"
import "core:math/ease"

import "../engine"

game_ui_debug :: proc() {
    when engine.IMGUI_ENABLE && ODIN_DEBUG {
        if _game.debug_show_demo_ui {
            engine.ui_debug_window_demo(&_game.debug_show_demo_ui)
        }

        if engine.ui_main_menu_bar() {
            if engine.ui_menu("Windows") {
                engine.ui_menu_item(fmt.tprintf("Debug %v", _game.debug_window_info ? "*" : ""), "F1", &_game.debug_window_info)
                engine.ui_menu_item(fmt.tprintf("Entities %v", _game.debug_ui_window_entities ? "*" : ""), "F2", &_game.debug_ui_window_entities)
                engine.ui_menu_item(fmt.tprintf("Assets %v", _game.debug_window_assets ? "*" : ""), "F3", &_game.debug_window_assets)
                engine.ui_menu_item(fmt.tprintf("Anim %v", _game.debug_window_anim ? "*" : ""), "F4", &_game.debug_window_anim)
                engine.ui_menu_item(fmt.tprintf("IMGUI Demo %v", _game.debug_show_demo_ui ? "*" : ""), "", &_game.debug_show_demo_ui)
            }
            if engine.ui_menu("Draw") {
                engine.ui_checkbox("Z-index=0", &_game.debug_render_z_index_0)
                engine.ui_checkbox("Z-index=1", &_game.debug_render_z_index_1)
                engine.ui_checkbox("Grid", &_game.debug_draw_grid)
                engine.ui_checkbox("Tiles", &_game.debug_draw_tiles)
                engine.ui_checkbox("Entities", &_game.debug_draw_entities)
                engine.ui_checkbox("Letterbox", &_game.draw_letterbox)
                engine.ui_checkbox("Bounding box", &_game.debug_show_bounding_boxes)
                engine.ui_checkbox("HUD", &_game.draw_hud)
            }
            if engine.ui_menu("Cheats") {
                engine.ui_checkbox("cheat_move_anywhere", &_game.cheat_move_anywhere)
                engine.ui_checkbox("cheat_act_anywhere",  &_game.cheat_act_anywhere)
            }
            window_size := _game._engine.platform.window_size
            if engine.ui_menu(fmt.tprintf("Window size: %ix%i", window_size.x, window_size.y)) {
                if engine.ui_menu_item("960x540", "", window_size == { 960, 540 }) { engine.platform_set_window_size(_game._engine.platform.window, { 960, 540 }) }
                if engine.ui_menu_item("1920x1080", "", window_size == { 1920, 1080 }) { engine.platform_set_window_size(_game._engine.platform.window, { 1920, 1080 }) }
                if engine.ui_menu_item("3840x2160", "", window_size == { 3840, 2160 }) { engine.platform_set_window_size(_game._engine.platform.window, { 3840, 2160 }) }
            }
            if engine.ui_menu(fmt.tprintf("Refresh rate: %vHz", _game._engine.renderer.refresh_rate)) {
                if engine.ui_menu_item("1Hz", "", _game._engine.renderer.refresh_rate == 1) { _game._engine.renderer.refresh_rate = 1 }
                if engine.ui_menu_item("10Hz", "", _game._engine.renderer.refresh_rate == 10) { _game._engine.renderer.refresh_rate = 10 }
                if engine.ui_menu_item("30Hz", "", _game._engine.renderer.refresh_rate == 30) { _game._engine.renderer.refresh_rate = 30 }
                if engine.ui_menu_item("60Hz", "", _game._engine.renderer.refresh_rate == 60) { _game._engine.renderer.refresh_rate = 60 }
                if engine.ui_menu_item("144Hz", "", _game._engine.renderer.refresh_rate == 144) { _game._engine.renderer.refresh_rate = 144 }
                if engine.ui_menu_item("240Hz", "", _game._engine.renderer.refresh_rate == 240) { _game._engine.renderer.refresh_rate = 240 }
                if engine.ui_menu_item("Unlocked", "", _game._engine.renderer.refresh_rate == 999999) { _game._engine.renderer.refresh_rate = 999999 }
            }
            if engine.ui_menu_item(("Reload shaders"), "P") {
                engine.debug_reload_shaders()
            }
        }

        { // Debug
            if _game.debug_window_info {
                if engine.ui_window("Debug", &_game.debug_window_info) {
                    engine.ui_set_window_size_vec2({ 600, 800 }, .FirstUseEver)
                    engine.ui_set_window_pos_vec2({ 50, 50 }, .FirstUseEver)

                    if engine.ui_tree_node("Memory", .DefaultOpen) {
                        resource_usage, resource_usage_previous := engine.mem_get_usage()
                        @(static) process_alloc_plot := engine.Statistic_Plot {}
                        engine.ui_statistic_plots(&process_alloc_plot, f32(resource_usage.ru_idrss), "process_mem")
                        frame_memory_usage := resource_usage.ru_idrss - resource_usage_previous.ru_idrss
                        engine.ui_text("process_memory: %v", resource_usage.ru_idrss)
                        @(static) frame_memory_alloc_plot := engine.Statistic_Plot {}
                        engine.ui_statistic_plots(&frame_memory_alloc_plot, f32(frame_memory_usage), "frame_mem")

                        engine.ui_progress_bar(f32(_game.engine_arena.offset) / f32(len(_game.engine_arena.data)), { -1, 20 }, engine.format_arena_usage(&_game.engine_arena))
                        engine.ui_progress_bar(f32(_game.game_arena.offset) / f32(len(_game.game_arena.data)), { -1, 20 }, engine.format_arena_usage(&_game.game_arena))
                    }

                    if engine.ui_tree_node("size_of") {
                        engine.ui_text("bool:  %v | b8:    %v | b16:   %v | b32:    %v | b64:   %v", size_of(bool), size_of(b8), size_of(b16), size_of(b32), size_of(b64))
                        engine.ui_text("int:   %v | i8:    %v | i16:   %v | i32:    %v | i64:   %v | i128:  %v", size_of(int), size_of(i8), size_of(i16), size_of(i32), size_of(i64), size_of(i128))
                        engine.ui_text("uint:  %v | u8:    %v | u16:   %v | u32:    %v | u64:   %v | u128:  %v | uintptr: %v", size_of(uint), size_of(u8), size_of(u16), size_of(u32), size_of(u64), size_of(u128), size_of(uintptr))
                        engine.ui_text("i16le: %v | i32le: %v | i64le: %v | i128le: %v | u16le: %v | u32le: %v | u64le:   %v | u128le: %v", size_of(i16le), size_of(i32le), size_of(i64le), size_of(i128le), size_of(u16le), size_of(u32le), size_of(u64le), size_of(u128le))
                        engine.ui_text("i16be: %v | i32be: %v | i64be: %v | i128be: %v | u16be: %v | u32be: %v | u64be:   %v | u128be: %v", size_of(i16be), size_of(i32be), size_of(i64be), size_of(i128be), size_of(u16be), size_of(u32be), size_of(u64be), size_of(u128be))
                        engine.ui_text("f16:   %v | f32:   %v | f64:   %v", size_of(f16), size_of(f32), size_of(f64))
                        engine.ui_text("f16le: %v | f32le: %v | f64le: %v", size_of(f16le), size_of(f32le), size_of(f64le))
                        engine.ui_text("f16be: %v | f32be: %v | f64be: %v", size_of(f16be), size_of(f32be), size_of(f64be))
                        engine.ui_text("complex32:    %v | complex64:     %v | complex128:    %v", size_of(complex32), size_of(complex64), size_of(complex128))
                        engine.ui_text("quaternion64: %v | quaternion128: %v | quaternion256: %v", size_of(quaternion64), size_of(quaternion128), size_of(quaternion256))
                        engine.ui_text("rune:   %v", size_of(rune))
                        engine.ui_text("string: %v | cstring: %v", size_of(string), size_of(cstring))
                        engine.ui_text("rawptr: %v", size_of(rawptr))
                        engine.ui_text("typeid: %v", size_of(typeid))
                        engine.ui_text("any:    %v", size_of(any))
                    }

                    if engine.ui_tree_node("Frame") {
                        @(static) locked_fps_plot := engine.Statistic_Plot {}
                        engine.ui_statistic_plots(&locked_fps_plot, f32(_game._engine.platform.locked_fps), "actual_fps")

                        @(static) frame_duration_plot := engine.Statistic_Plot {}
                        engine.ui_statistic_plots(&frame_duration_plot, f32(_game._engine.platform.frame_duration), "frame_duration")

                        @(static) delta_time_plot := engine.Statistic_Plot {}
                        engine.ui_statistic_plots(&delta_time_plot, f32(_game._engine.platform.delta_time), "delta_time", "%2.5f")

                        engine.ui_text("Refresh rate:   %3.0fHz", f32(_game._engine.renderer.refresh_rate))
                        engine.ui_text("Actual FPS:     %5.0f", f32(_game._engine.platform.actual_fps))
                        engine.ui_text("Frame duration: %2.6fms", _game._engine.platform.frame_duration)
                        engine.ui_text("Frame delay:    %2.6fms", _game._engine.platform.frame_delay)
                        engine.ui_text("Delta time:     %2.6fms", _game._engine.platform.delta_time)
                    }

                    if engine.ui_tree_node("Renderer") {
                        engine.ui_text("rendering_size:    %v", _game._engine.renderer.rendering_size)
                        engine.ui_text("native_resolution: %v", _game._engine.renderer.native_resolution)
                        engine.ui_text("ideal_scale:       %v", _game._engine.renderer.ideal_scale)

                        if engine.ui_tree_node("camera: world", .DefaultOpen) {
                            camera := &_game._engine.renderer.world_camera
                            engine.ui_slider_float3("position", transmute(^[3]f32)&camera.position, -100, 100)
                            engine.ui_slider_float("rotation", &camera.rotation, 0, math.TAU)
                            engine.ui_input_float("zoom", &camera.zoom, 1)
                            if engine.ui_button("Reset zoom") {
                                camera.zoom = _game._engine.renderer.ideal_scale
                                camera.rotation = 0
                            }
                            if engine.ui_tree_node("projection_matrix") {
                                engine.ui_slider_float4("projection_matrix[0]", &camera.projection_matrix[0], -1, 1)
                                engine.ui_slider_float4("projection_matrix[1]", &camera.projection_matrix[1], -1, 1)
                                engine.ui_slider_float4("projection_matrix[2]", &camera.projection_matrix[2], -1, 1)
                                engine.ui_slider_float4("projection_matrix[3]", &camera.projection_matrix[3], -1, 1)
                            }
                            if engine.ui_tree_node("view_matrix") {
                                engine.ui_slider_float4("view_matrix[0]", &camera.view_matrix[0], -1, 1)
                                engine.ui_slider_float4("view_matrix[1]", &camera.view_matrix[1], -1, 1)
                                engine.ui_slider_float4("view_matrix[2]", &camera.view_matrix[2], -1, 1)
                                engine.ui_slider_float4("view_matrix[3]", &camera.view_matrix[3], -1, 1)
                            }
                            if engine.ui_tree_node("projection_view_matrix", .DefaultOpen) {
                                engine.ui_slider_float4("projection_view_matrix[0]", &camera.projection_view_matrix[0], -1, 1, "%.3f", .NoInput)
                                engine.ui_slider_float4("projection_view_matrix[1]", &camera.projection_view_matrix[1], -1, 1, "%.3f", .NoInput)
                                engine.ui_slider_float4("projection_view_matrix[2]", &camera.projection_view_matrix[2], -1, 1, "%.3f", .NoInput)
                                engine.ui_slider_float4("projection_view_matrix[3]", &camera.projection_view_matrix[3], -1, 1, "%.3f", .NoInput)
                            }
                        }

                        if engine.ui_tree_node("camera: ui") {
                            camera := &_game._engine.renderer.ui_camera
                            engine.ui_slider_float3("position", transmute(^[3]f32)&camera.position, -100, 100)
                            engine.ui_slider_float("rotation", &camera.rotation, 0, math.TAU)
                            engine.ui_input_float("zoom", &camera.zoom, 1)
                            if engine.ui_button("Reset zoom") {
                                camera.zoom = _game._engine.renderer.ideal_scale
                                camera.rotation = 0
                            }
                            if engine.ui_tree_node("projection_matrix") {
                                engine.ui_slider_float4("projection_matrix[0]", &camera.projection_matrix[0], -1, 1)
                                engine.ui_slider_float4("projection_matrix[1]", &camera.projection_matrix[1], -1, 1)
                                engine.ui_slider_float4("projection_matrix[2]", &camera.projection_matrix[2], -1, 1)
                                engine.ui_slider_float4("projection_matrix[3]", &camera.projection_matrix[3], -1, 1)
                            }
                            if engine.ui_tree_node("view_matrix") {
                                engine.ui_slider_float4("view_matrix[0]", &camera.view_matrix[0], -1, 1)
                                engine.ui_slider_float4("view_matrix[1]", &camera.view_matrix[1], -1, 1)
                                engine.ui_slider_float4("view_matrix[2]", &camera.view_matrix[2], -1, 1)
                                engine.ui_slider_float4("view_matrix[3]", &camera.view_matrix[3], -1, 1)
                            }
                            if engine.ui_tree_node("projection_view_matrix") {
                                engine.ui_slider_float4("projection_view_matrix[0]", &camera.projection_view_matrix[0], -1, 1, "%.3f", .NoInput)
                                engine.ui_slider_float4("projection_view_matrix[1]", &camera.projection_view_matrix[1], -1, 1, "%.3f", .NoInput)
                                engine.ui_slider_float4("projection_view_matrix[2]", &camera.projection_view_matrix[2], -1, 1, "%.3f", .NoInput)
                                engine.ui_slider_float4("projection_view_matrix[3]", &camera.projection_view_matrix[3], -1, 1, "%.3f", .NoInput)
                            }
                        }
                    }
                }
            }
        }

        // Assets
        engine.ui_debug_window_notification()
        engine.ui_debug_window_assets(&_game.debug_window_assets)

        { // Animation
            if _game.debug_window_anim {
                if engine.ui_window("Animations", &_game.debug_window_anim) {
                    engine.ui_set_window_size_vec2({ 1200, 150 }, .FirstUseEver)
                    engine.ui_set_window_pos_vec2({ 700, 50 }, .FirstUseEver)

                    { // Debug animation
                        @(static) i_time: f32 = 0
                        i_time += _game._engine.platform.delta_time / 1000
                        speed : f32 = 1
                        engine.ui_slider_float("speed", &speed, 0, 10)

                        @(static) progress : f32 = 0
                        // progress = (math.sin(i_time * speed) + 1) / 2
                        progress += _game._engine.platform.delta_time / 1000 * speed
                        if progress > 1 {
                            progress = 0
                        }

                        sprite_index : i8 = 0
                        if engine.ui_tree_node("Sprite", .DefaultOpen) {
                            animation_sprite := []engine.Animation_Step(i8) {
                                { t = 0.0, value = 0, },
                                { t = 0.2, value = 1, },
                                { t = 0.4, value = 2, },
                                { t = 0.6, value = 3, },
                                { t = 0.8, value = 4, },
                                { t = 1.0, value = 5, },
                            }
                            sprite_index = engine.animation_lerp_value(animation_sprite, progress)
                            engine.ui_text("sprite_index:            %v", sprite_index)
                            engine.ui_animation_plot("sprite_index", animation_sprite)
                        }

                        color := Vector4f32 { 1, 1, 1, 1 }
                        if engine.ui_tree_node("Color") {
                            animation_color := []engine.Animation_Step(Vector4f32) {
                                { t = 0.0, value = { 0.0, 0.0, 1.0, 1 } },
                                { t = 0.5, value = { 0.0, 1.0, 0.5, 1 } },
                                { t = 1.0, value = { 1.0, 1.0, 1.0, 1 } },
                            }
                            color = engine.animation_lerp_value(animation_color, progress)
                            engine.ui_color_edit4("animation_color", transmute(^[4]f32)&color.r)
                            engine.ui_animation_plot("animation_color", animation_color)
                        }

                        engine.ui_slider_float("progress", &progress, 0, 1)

                        { // Nyan
                            texture_asset, texture_asset_ok := slice.get(_game._engine.assets.assets, int(_game.asset_nyan))
                            texture_asset_info, texture_asset_info_ok := texture_asset.info.(engine.Asset_Info_Image)
                            entity_texture_position := engine.grid_index_to_position(int(sprite_index), 6) * 40
                            engine.ui_text("entity_texture_position: %v", entity_texture_position)
                            texture_position, texture_size, pixel_size := texture_position_and_size(texture_asset_info.texture, entity_texture_position, { 40, 32 }, 10)
                            engine.ui_image(
                                auto_cast(uintptr(texture_asset_info.texture.renderer_id)),
                                { 80, 80 },
                                { texture_position.x, texture_position.y },
                                { texture_position.x + texture_size.x, texture_position.y + texture_size.y },
                                transmute(engine.UI_Vec4) color,
                            )
                        }
                    }
                }
            }
        }

        { // Entities
            if _game.debug_ui_window_entities {
                if engine.ui_window("Entities", &_game.debug_ui_window_entities) {
                    engine.ui_set_window_size_vec2({ 600, 800 }, .FirstUseEver)
                    engine.ui_set_window_pos_vec2({ 50, 50 }, .FirstUseEver)

                    engine.ui_text(fmt.tprintf("Entities: %v", len(_game.entities.entities)))

                    engine.ui_checkbox("Highlight current", &_game.debug_ui_entity_highlight)

                    engine.ui_text("Current entity")
                    engine.ui_same_line()
                    engine.ui_push_item_width(100)
                    engine.ui_input_int("", cast(^i32) &_game.debug_ui_entity)

                    if engine.ui_collapsing_header("Grid", .DefaultOpen) {
                        @(static) hovered_entity : Entity = 0
                        engine.ui_text(fmt.tprintf("hovered_entity: %v", entity_format(hovered_entity, &_game.entities)))

                        draw_list := engine.ui_get_foreground_draw_list()
                        origin := engine.UI_Vec2 {}
                        engine.ui_get_item_rect_min(&origin)
                        line_height : f32 = 17
                        x : f32 = origin.x
                        y : f32 = origin.y + line_height
                        size : f32 = 10
                        spacing : f32 = 4
                        entities_per_row := 30
                        total_height := math.floor(f32(len(_game.entities.entities)) / f32(entities_per_row)) * (size + spacing) + line_height
                        window_pos := engine.ui_get_window_pos()
                        window_size := engine.ui_get_window_size()
                        window_end := window_size.y - f32(y)
                        engine.ui_dummy({ -1, total_height })
                        for entity, i in _game.entities.entities {
                            if i > 0 && i % entities_per_row == 0 {
                                y += size + spacing
                                x = origin.x
                            }
                            if window_pos.y + window_size.y - y <= line_height || window_pos.y - y >= -line_height {
                                continue
                            }
                            color := engine.UI_Vec4 { 0.0, 0.5, 0.5, 1 }
                            if entity_has_flag(entity, .Tile) {
                                color = { 0.5, 0.5, 0, 1 }
                            }
                            engine.ui_draw_list_add_rect_filled(draw_list, { x, y }, { x + size, y + size }, engine.ui_get_color_u32_vec4(color))

                            if engine.ui_is_mouse_hovering_rect({ x - spacing / 2, y - spacing / 2 }, { x + size + spacing / 2, y + size + spacing / 2 }) {
                                hovered_entity = entity
                                if engine.ui_is_mouse_clicked(.Left) {
                                    if _game.debug_ui_entity == entity {
                                        _game.debug_ui_entity = 0
                                    } else {
                                        _game.debug_ui_entity = entity
                                    }
                                }
                            }

                            if slice.contains(_game.battle_data.entities[:], entity) {
                                engine.ui_draw_list_add_rect_filled(draw_list, { x + 1, y + 1 }, { x + 4, y + 4 }, engine.ui_get_color_u32_vec4({ 1, 1, 1, 0.8 }))
                            }
                            if entity_has_flag(entity, .Unit) {
                                engine.ui_draw_list_add_rect_filled(draw_list, { x + 5, y + 1 }, { x + 9, y + 4 }, engine.ui_get_color_u32_vec4({ 1, 0, 0, 0.8 }))
                            }

                            x += size + spacing
                        }
                    }

                    if engine.ui_collapsing_header("List") {
                        engine.ui_checkbox("Hide tiles", &_game.debug_ui_no_tiles)

                        columns := [?]string { "id", "name", "actions" }
                        if engine.ui_begin_table("table1", len(columns), .RowBg | .SizingStretchSame | .Resizable) {

                            engine.ui_table_next_row(.Headers)
                            for column, i in columns {
                                engine.ui_table_set_column_index(i32(i))
                                engine.ui_text(column)
                            }

                            for entity in _game.entities.entities {
                                component_flag, has_flag := _game.entities.components_flag[entity]
                                if _game.debug_ui_no_tiles && has_flag && .Tile in component_flag.value {
                                    continue
                                }

                                engine.ui_table_next_row()

                                for column, i in columns {
                                    engine.ui_table_set_column_index(i32(i))
                                    switch column {
                                        case "id": engine.ui_text(fmt.tprintf("%v", entity))
                                        // case "state": engine.ui_text(fmt.tprintf("%v", asset.state))
                                        // case "type": engine.ui_text(fmt.tprintf("%v", asset.type))
                                        case "name": engine.ui_text(fmt.tprintf("%v", _game.entities.components_name[entity].name))
                                        case "actions": {
                                            engine.ui_push_id(i32(entity))
                                            if engine.ui_button("Inspect") {
                                                if _game.debug_ui_entity == entity {
                                                    _game.debug_ui_entity = 0
                                                } else {
                                                    _game.debug_ui_entity = entity
                                                }
                                            }
                                            engine.ui_pop_id()
                                        }
                                        case: engine.ui_text("x")
                                    }
                                }
                            }
                            engine.ui_end_table()
                        }
                    }
                }
            }

            entity := _game.debug_ui_entity
            if entity != Entity(0) {
                if engine.ui_window("Entity", cast(^bool) &_game.debug_ui_entity) {
                    engine.ui_set_window_size_vec2({ 300, 300 }, .FirstUseEver)
                    engine.ui_set_window_pos_vec2({ 500, 500 }, .FirstUseEver)

                    engine.ui_text("id:")
                    engine.ui_same_line(0, 10)
                    engine.ui_text("%v", entity)

                    if engine.ui_button("Hide all others") {
                        for other, component_rendering in _game.entities.components_rendering {
                            if entity != other {
                                (&_game.entities.components_rendering[other]).visible = false
                            }
                        }
                    }

                    component_name, has_name := _game.entities.components_name[entity]
                    if has_name {
                        if engine.ui_collapsing_header("Component_Name", .DefaultOpen) {
                            engine.ui_text("name:")
                            engine.ui_same_line(0, 10)
                            engine.ui_text(component_name.name)
                        }
                    }

                    component_transform, has_transform := &_game.entities.components_transform[entity]
                    if has_transform {
                        rect_position := component_transform.world_position * component_transform.size
                        // engine.append_debug_rect({ rect_position.x, rect_position.y, component_transform.size.x, component_transform.size.y }, { 255, 0, 0, 100 })
                        if engine.ui_collapsing_header("Component_Transform", .DefaultOpen) {
                            engine.ui_slider_int2("grid_position", transmute(^[2]i32)(&component_transform.grid_position), 0, 1024)
                            engine.ui_slider_float2("world_position", transmute(^[2]f32)(&component_transform.world_position), 0, 1024)
                            engine.ui_slider_float2("size", transmute(^[2]f32)(&component_transform.size), 0, 1024)
                        }
                    }

                    component_rendering, has_rendering := &_game.entities.components_rendering[entity]
                    if has_rendering {
                        if engine.ui_collapsing_header("Component_Rendering", .DefaultOpen) {
                            engine.ui_checkbox("visible", &component_rendering.visible)

                            engine.ui_text("texture_asset:")
                            engine.ui_same_line(0, 10)
                            engine.ui_text("%v", component_rendering.texture_asset)
                            engine.ui_push_item_width(224)
                            engine.ui_input_int("texture_asset", transmute(^i32) &component_rendering.texture_asset, 1, 1)
                            engine.ui_pop_item_width()

                            engine.ui_text("texture_position:")
                            engine.ui_same_line(0, 10)
                            engine.ui_text("%v", component_rendering.texture_position)
                            engine.ui_slider_int2("texture_position", transmute(^[2]i32)(&component_rendering.texture_position), 0, 256)
                            engine.ui_text("texture_size:")
                            engine.ui_same_line(0, 10)
                            engine.ui_text("%v", component_rendering.texture_size)
                            engine.ui_slider_int2("texture_size", transmute(^[2]i32)(&component_rendering.texture_size), 0, 256)
                            engine.ui_push_item_width(224)
                            engine.ui_input_int("texture_padding", &component_rendering.texture_padding, 1, 1)

                            engine.ui_push_item_width(224)
                            engine.ui_input_int("z_index", &component_rendering.z_index, 1, 1)

                            asset, asset_exists := slice.get(_game._engine.assets.assets, int(component_rendering.texture_asset))
                            if component_rendering.texture_asset >= 0 && int(component_rendering.texture_asset) < len(_game._engine.assets.assets) {
                                asset_info, asset_ok := asset.info.(engine.Asset_Info_Image)
                                if asset_ok {
                                    texture_position, texture_size, pixel_size := texture_position_and_size(asset_info.texture, component_rendering.texture_position, component_rendering.texture_size)
                                    engine.ui_image(
                                        auto_cast(uintptr(asset_info.texture.renderer_id)),
                                        { 80, 80 },
                                        { texture_position.x, texture_position.y },
                                        { texture_position.x + texture_size.x, texture_position.y + texture_size.y },
                                    )
                                    engine.ui_text("%v -> %v/%v", texture_position, texture_size, pixel_size)
                                }
                            }
                        }
                    }

                    component_animation, has_animation := &_game.entities.components_animation[entity]
                    if has_animation {
                        if engine.ui_collapsing_header("Component_Animation", .DefaultOpen) {
                            engine.ui_slider_float("t", &component_animation.t, 0, 1)
                            for step in component_animation.steps_sprite {
                                engine.ui_text("%v -> %v (%v)", step.t, step.value, step.ease)
                            }
                            for step in component_animation.steps_color {
                                engine.ui_text("%v -> %v (%v)", step.t, step.value, step.ease)
                            }
                        }
                    }

                    component_flag, has_flag := _game.entities.components_flag[entity]
                    if has_flag {
                        if engine.ui_collapsing_header("Component_Flag", .DefaultOpen) {
                            engine.ui_text("value:")
                            engine.ui_same_line(0, 10)
                            engine.ui_text("%v", component_flag.value)
                        }
                    }

                    component_meta, has_meta := _game.entities.components_meta[entity]
                    if has_meta {
                        if engine.ui_collapsing_header("Component_Meta", .DefaultOpen) {
                            engine.ui_text("entity_uid:")
                            engine.ui_same_line(0, 10)
                            engine.ui_text("%v", component_meta.entity_uid)
                        }
                    }
                }
            }
        }
    }
}

// game_ui_debug_windows :: proc() {
//     if engine.renderer_is_enabled() == false do return
//     if _game._engine.renderer.rendering_size == 0 do return

//     if engine.HOT_RELOAD_CODE && time.diff(_game._engine.debug.last_reload, time.now()) < time.Millisecond * 1000 {
//         if engine.ui_window("Code reloaded", { _game._engine.platform.window_size.x - 190, _game._engine.platform.window_size.y - 80, 170, 60 }, { .NO_CLOSE, .NO_RESIZE }) {
//             engine.ui_layout_row({ -1 }, 0)
//             engine.ui_label(fmt.tprintf("Reloaded at: %v", time.time_to_unix(_game._engine.debug.last_reload)))
//         }
//     }

//     if _game.debug_ui_window_info {
//         if engine.ui_window("Debug", { 0, 0, 500, _game._engine.platform.window_size.y }, { .NO_CLOSE }) {
//             if .ACTIVE in engine.ui_header("Memory", { .EXPANDED }) {
//                 engine.ui_layout_row({ 50, 50, 50, 50 }, 0)
//                 if .SUBMIT in engine.ui_button("Save 1") {
//                     _game._engine.debug.save_memory = 1
//                 }
//                 if .SUBMIT in engine.ui_button("Save 2") {
//                     _game._engine.debug.save_memory = 2
//                 }
//                 if .SUBMIT in engine.ui_button("Save 3") {
//                     _game._engine.debug.save_memory = 3
//                 }
//                 if .SUBMIT in engine.ui_button("Save 4") {
//                     _game._engine.debug.save_memory = 4
//                 }
//                 engine.ui_layout_row({ 50, 50, 50, 50 }, 0)
//                 if .SUBMIT in engine.ui_button("Load 1") {
//                     _game._engine.debug.load_memory = 1
//                 }
//                 if .SUBMIT in engine.ui_button("Load 2") {
//                     _game._engine.debug.load_memory = 2
//                 }
//                 if .SUBMIT in engine.ui_button("Load 3") {
//                     _game._engine.debug.load_memory = 3
//                 }
//                 if .SUBMIT in engine.ui_button("Load 4") {
//                     _game._engine.debug.load_memory = 4
//                 }

//                 {
//                     engine.ui_layout_row({ 100, -1 }, 0)
//                     engine.ui_label("engine")
//                     engine.ui_label(engine.format_arena_usage(&_game.engine_arena))
//                     engine.ui_layout_row({ -1 }, 0)
//                     engine.ui_progress_bar(f32(_game.engine_arena.offset) / f32(len(_game.engine_arena.data)), 5)
//                 }
//                 {
//                     engine.ui_layout_row({ 100, -1 }, 0)
//                     engine.ui_label("game")
//                     engine.ui_label(engine.format_arena_usage(&_game.game_arena))
//                     engine.ui_layout_row({ -1 }, 0)
//                     engine.ui_progress_bar(f32(_game.game_arena.offset) / f32(len(_game.game_arena.data)), 5)
//                 }
//                 {
//                     arena := cast(^mem.Arena)_game.game_mode.allocator.data
//                     engine.ui_layout_row({ 100, -1 }, 0)
//                     engine.ui_label("game_mode")
//                     engine.ui_label(engine.format_arena_usage(arena))
//                     engine.ui_layout_row({ -1 }, 0)
//                     engine.ui_progress_bar(f32(arena.offset) / f32(len(arena.data)), 5)
//                 }
//             }

//             if .ACTIVE in engine.ui_header("Config", { .EXPANDED }) {
//                 engine.ui_layout_row({ 170, -1 }, 0)
//                 engine.ui_label("Last code reload")
//                 engine.ui_label(fmt.tprintf("%v", time.time_to_unix(_game._engine.debug.last_reload)))
//                 engine.ui_label("ODIN_DEBUG")
//                 engine.ui_label(fmt.tprintf("%v", ODIN_DEBUG))
//                 engine.ui_label("RENDERER_DEBUG")
//                 engine.ui_label(fmt.tprintf("%v", engine.RENDERER_DEBUG))
//                 engine.ui_label("PROFILER")
//                 engine.ui_label(fmt.tprintf("%v", engine.PROFILER))
//                 engine.ui_label("HOT_RELOAD_CODE")
//                 engine.ui_label(fmt.tprintf("%v", engine.HOT_RELOAD_CODE))
//                 engine.ui_label("HOT_RELOAD_ASSETS")
//                 engine.ui_label(fmt.tprintf("%v", engine.HOT_RELOAD_ASSETS))
//                 engine.ui_label("ASSETS_PATH")
//                 engine.ui_label(fmt.tprintf("%v", engine.ASSETS_PATH))
//             }

//             if .ACTIVE in engine.ui_header("Game", { .EXPANDED }) {
//                 engine.ui_layout_row({ 170, -1 }, 0)
//                 engine.ui_label("window_size")
//                 engine.ui_label(fmt.tprintf("%v", _game._engine.platform.window_size))
//                 engine.ui_label("FPS")
//                 engine.ui_label(fmt.tprintf("%v", 1 / _game._engine.platform.delta_time))
//                 engine.ui_label("Game_Mode")
//                 engine.ui_label(fmt.tprintf("%v", _game.game_mode.current))
//                 engine.ui_label("draw_letterbox")
//                 engine.ui_label(fmt.tprintf("%v", _game.draw_letterbox))
//                 // engine.ui_label("mouse_screen_position")
//                 // engine.ui_label(fmt.tprintf("%v", _game.mouse_screen_position))
//                 // engine.ui_label("mouse_grid_position")
//                 // engine.ui_label(fmt.tprintf("%v", _game.mouse_grid_position))
//                 // engine.ui_label("party")
//                 // engine.ui_label(fmt.tprintf("%v", _game.party))
//             }

//             if .ACTIVE in engine.ui_header("Debug", { .EXPANDED }) {
//                 engine.ui_layout_row({ 170, -1 })
//                 engine.ui_label("debug_ui_window_info")
//                 engine.ui_label(fmt.tprintf("%v", _game.debug_ui_window_info))
//                 engine.ui_label("debug_ui_window_entities")
//                 engine.ui_label(fmt.tprintf("%v", _game.debug_ui_window_entities))
//                 engine.ui_label("debug_ui_no_tiles")
//                 engine.ui_label(fmt.tprintf("%v", _game.debug_ui_no_tiles))
//                 engine.ui_label("debug_ui_room_only")
//                 engine.ui_label(fmt.tprintf("%v", _game.debug_ui_room_only))
//                 engine.ui_label("debug_ui_entity")
//                 engine.ui_label(fmt.tprintf("%v", _game.debug_ui_entity))
//                 engine.ui_label("debug_draw_tiles")
//                 engine.ui_label(fmt.tprintf("%v", _game.debug_draw_tiles))
//                 engine.ui_label("debug_show_bounding_boxes")
//                 engine.ui_label(fmt.tprintf("%v", _game.debug_show_bounding_boxes))
//                 engine.ui_label("debug_entity_under_mouse")
//                 engine.ui_label(fmt.tprintf("%v", _game.debug_entity_under_mouse))
//             }

//             if .ACTIVE in engine.ui_header("Platform", { .EXPANDED }) {
//                 engine.ui_layout_row({ 170, -1 })
//                 engine.ui_label("mouse_position")
//                 engine.ui_label(fmt.tprintf("%v", _game._engine.platform.mouse_position))

//                 if .ACTIVE in engine.ui_treenode("Inputs", { }) {
//                     engine.ui_layout_row({ 50, 50, -1 }, 0)
//                     engine.ui_label("axis")
//                     engine.ui_label("x")
//                     engine.ui_label("y")
//                     {
//                         axis := _game.player_inputs.move
//                         engine.ui_label("move")
//                         engine.ui_label(fmt.tprintf("%v", axis.x))
//                         engine.ui_label(fmt.tprintf("%v", axis.y))
//                     }

//                     engine.ui_layout_row({ 50, 50, 50, 50, 50 }, 0)
//                     engine.ui_label("key")
//                     engine.ui_label("down")
//                     engine.ui_label("up")
//                     engine.ui_label("pressed")
//                     engine.ui_label("released")
//                     {
//                         using _game.player_inputs.confirm
//                         engine.ui_label("confirm")
//                         engine.ui_label(fmt.tprintf("%v", down))
//                         engine.ui_label(fmt.tprintf("%v", !down))
//                         engine.ui_label(fmt.tprintf("%v", pressed))
//                         engine.ui_label(fmt.tprintf("%v", released))
//                     }
//                     {
//                         using _game.player_inputs.cancel
//                         engine.ui_label("cancel")
//                         engine.ui_label(fmt.tprintf("%v", down))
//                         engine.ui_label(fmt.tprintf("%v", !down))
//                         engine.ui_label(fmt.tprintf("%v", pressed))
//                         engine.ui_label(fmt.tprintf("%v", released))
//                     }
//                 }

//                 if .ACTIVE in engine.ui_treenode("Controllers", { }) {
//                     keys := [] engine.GameControllerButton {
//                         .A,
//                         .B,
//                         .X,
//                         .Y,
//                         .BACK,
//                         // .GUIDE,
//                         .START,
//                         .LEFTSTICK,
//                         .RIGHTSTICK,
//                         .LEFTSHOULDER,
//                         .RIGHTSHOULDER,
//                         .DPAD_UP,
//                         .DPAD_DOWN,
//                         .DPAD_LEFT,
//                         .DPAD_RIGHT,
//                         // .MISC1,
//                         // .PADDLE1,
//                         // .PADDLE2,
//                         // .PADDLE3,
//                         // .PADDLE4,
//                         // .TOUCHPAD,
//                         // .MAX,
//                     }
//                     axes := [] engine.GameControllerAxis {
//                         // .INVALID = -1,
//                         .LEFTX,
//                         .LEFTY,
//                         .RIGHTX,
//                         .RIGHTY,
//                         .TRIGGERLEFT,
//                         .TRIGGERRIGHT,
//                         // .MAX,
//                     }

//                     for joystick_id, controller_state in _game._engine.platform.controllers {
//                         controller_name := engine.platform_get_controller_name(controller_state.controller)
//                         if .ACTIVE in engine.ui_treenode(fmt.tprintf("%v (%v)", controller_name, joystick_id), { .EXPANDED }) {
//                             engine.ui_layout_row({ 90, 50, 50, 50, 50 })
//                             engine.ui_label("key")
//                             engine.ui_label("down")
//                             engine.ui_label("up")
//                             engine.ui_label("pressed")
//                             engine.ui_label("released")
//                             for key in keys {
//                                 engine.ui_label(fmt.tprintf("%v", key))
//                                 engine.ui_label(fmt.tprintf("%v", controller_state.buttons[key].down))
//                                 engine.ui_label(fmt.tprintf("%v", !controller_state.buttons[key].down))
//                                 engine.ui_label(fmt.tprintf("%v", controller_state.buttons[key].pressed))
//                                 engine.ui_label(fmt.tprintf("%v", controller_state.buttons[key].released))
//                             }

//                             engine.ui_layout_row({ 90, 50 })
//                             engine.ui_label("axis")
//                             engine.ui_label("value")
//                             for axis in axes {
//                                 engine.ui_label(fmt.tprintf("%v", axis))
//                                 engine.ui_label(fmt.tprintf("%v", controller_state.axes[axis].value))
//                             }
//                         }
//                     }
//                 }

//                 if .ACTIVE in engine.ui_treenode("Keyboard", { }) {
//                     keys := [] engine.Scancode {
//                         .UP,
//                         .DOWN,
//                         .LEFT,
//                         .RIGHT,
//                     }
//                     engine.ui_layout_row({ 50, 50, 50, 50, 50 }, 0)
//                     engine.ui_label("key")
//                     engine.ui_label("down")
//                     engine.ui_label("up")
//                     engine.ui_label("pressed")
//                     engine.ui_label("released")
//                     for key in keys {
//                         engine.ui_label(fmt.tprintf("%v", key))
//                         engine.ui_label(fmt.tprintf("%v", _game._engine.platform.keys[key].down))
//                         engine.ui_label(fmt.tprintf("%v", !_game._engine.platform.keys[key].down))
//                         engine.ui_label(fmt.tprintf("%v", _game._engine.platform.keys[key].pressed))
//                         engine.ui_label(fmt.tprintf("%v", _game._engine.platform.keys[key].released))
//                     }
//                 }
//             }

//             if .ACTIVE in engine.ui_header("Renderer", { .EXPANDED }) {
//                 engine.ui_layout_row({ 170, -1 }, 0)
//                 engine.ui_label("pixel_density")
//                 engine.ui_label(fmt.tprintf("%v", _game._engine.renderer.pixel_density))
//                 engine.ui_label("rendering_size")
//                 engine.ui_label(fmt.tprintf("%v", _game._engine.renderer.rendering_size))
//                 engine.ui_label("rendering_scale")
//                 engine.ui_label(fmt.tprintf("%v", _game._engine.renderer.rendering_scale))
//                 engine.ui_label("rendering_offset")
//                 engine.ui_label(fmt.tprintf("%v", _game._engine.renderer.rendering_offset))
//                 engine.ui_layout_row({ 50, 50, 50, 50, 50, 50, 50, 50 }, 0)
//                 scales := []i32 { 1, 2, 3, 4, 5, 6 }
//                 for scale in scales {
//                     if .SUBMIT in engine.ui_button(fmt.tprintf("x%i", scale)) {
//                         log.debugf("Set rendering_scale: %v", scale)
//                         _game._engine.renderer.rendering_scale = scale
//                     }
//                 }
//                 engine.ui_layout_row({ 170, -1 }, 0)
//                 // engine.ui_label("textures")
//                 // engine.ui_label(fmt.tprintf("%v", len(_game._engine.renderer.textures)))
//             }
//         }
//     }
// }

THEME_BG            :: engine.UI_Vec4 { 0.1568627450980392, 0.16470588235294117, 0.21176470588235294, 1 }
THEME_BG_FADED      :: engine.UI_Vec4 { 0.26666666666666666, 0.2784313725490196, 0.35294117647058826, 1 }
THEME_BG_FOCUSED    :: engine.UI_Vec4 { 0.36, 0.37, 0.45, 1 }
THEME_FOREGROUND    :: engine.UI_Vec4 { 0.5725490196078431, 0.3764705882352941, 0.6705882352941176, 1 }
THEME_HIGH_ACCENT   :: engine.UI_Vec4 { 1, 0.4745098039215686, 0.7764705882352941, 1 }
THEME_ACCENT        :: engine.UI_Vec4 { 0.7411764705882353, 0.5764705882352941, 0.9764705882352941, 1 }
THEME_FADED         :: engine.UI_Vec4 { 0.3843137254901961, 0.4470588235294118, 0.6431372549019608, 1 }
THEME_RED           :: engine.UI_Vec4 { 1, 0.3333333333333333, 0.27058823529411763, 1 }
THEME_GREEN         :: engine.UI_Vec4 { 0.25882352941176473, 1, 0.13333333333333333, 1 }
THEME_WARNING       :: engine.UI_Vec4 { 0.9215686274509803, 0.5568627450980392, 0.25882352941176473, 1 }
THEME_WHITE         :: engine.UI_Vec4 { 0.9725490196078431, 0.9725490196078431, 0.9490196078431372, 1 }
THEME_GENERIC_ASSET :: engine.UI_Vec4 { 1, 0.4, 0.6, 1 }
THEME_YELLOW        :: engine.UI_Vec4 { 0.9450980392156862, 0.9803921568627451, 0.5490196078431373, 1 }

@(deferred_out=game_ui_window_end)
game_ui_window :: proc(name: string, open : ^bool = nil, flags := engine.Window_Flags(0)) -> bool {
    when engine.IMGUI_ENABLE {
        ui_push_theme()
        return engine.ui_begin(name, open, flags)
    } else {
        return false
    }
}

@(private="file")
game_ui_window_end :: proc(collapsed: bool) {
    when engine.IMGUI_ENABLE {
        engine._ui_end(collapsed)
        ui_pop_theme()
    }
}

ui_push_theme :: proc() {
    engine.ui_push_style_var(.FrameRounding, 3)
    engine.ui_push_style_var(.PopupRounding, 3)
    engine.ui_push_style_var(.WindowRounding, 6)

    engine.ui_push_style_color(.Text, THEME_WHITE)
    engine.ui_push_style_color(.PopupBg, THEME_BG)
    engine.ui_push_style_color(.WindowBg, THEME_BG)
    engine.ui_push_style_color(.TitleBg, THEME_BG_FADED)
    engine.ui_push_style_color(.TitleBgActive, THEME_FADED)

    engine.ui_push_style_color(.TextSelectedBg, THEME_ACCENT)
    engine.ui_push_style_color(.ChildBg, THEME_BG)

    engine.ui_push_style_color(.PopupBg, THEME_BG)

    engine.ui_push_style_color(.Header, THEME_FADED)
    engine.ui_push_style_color(.HeaderActive, THEME_ACCENT)
    engine.ui_push_style_color(.HeaderHovered, THEME_ACCENT)

    engine.ui_push_style_color(.TabActive, THEME_ACCENT)
    engine.ui_push_style_color(.TabHovered, THEME_HIGH_ACCENT)
    engine.ui_push_style_color(.TabUnfocused, THEME_BG_FADED)
    engine.ui_push_style_color(.TabUnfocusedActive, THEME_HIGH_ACCENT)
    engine.ui_push_style_color(.Tab, THEME_BG_FADED)
    // engine.ui_push_style_color(.DockingEmptyBg, THEME_BG_FADED)
    // engine.ui_push_style_color(.DockingPreview, THEME_FADED)

    engine.ui_push_style_color(.Button, THEME_FOREGROUND)
    engine.ui_push_style_color(.ButtonActive, THEME_HIGH_ACCENT)
    engine.ui_push_style_color(.ButtonHovered, THEME_ACCENT)

    engine.ui_push_style_color(.FrameBg, THEME_BG_FADED)
    engine.ui_push_style_color(.FrameBgActive, THEME_BG_FOCUSED)
    engine.ui_push_style_color(.FrameBgHovered, THEME_BG_FOCUSED)

    engine.ui_push_style_color(.SeparatorActive, THEME_ACCENT)
    engine.ui_push_style_color(.ButtonActive, THEME_HIGH_ACCENT)
}

ui_pop_theme :: proc() {
    engine.ui_pop_style_color(24)
    engine.ui_pop_style_var(3)
}
