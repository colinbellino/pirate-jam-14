package game

import "core:runtime"
import "core:slice"

import platform "../engine/platform"
import renderer "../engine/renderer"
import ui "../engine/renderer/ui"
import logger "../engine/logger"
import profiler "../engine/profiler"

game_render :: proc(
    arena_allocator: runtime.Allocator,
    delta_time: f64,
    game_state: ^Game_State,
    platform_state: ^platform.Platform_State,
    renderer_state: ^renderer.Renderer_State,
    logger_state: ^logger.Logger_State,
    ui_state: ^ui.UI_State,
) {
    profiler.profiler_start("render");

    if platform_state.window_resized {
        game_state.window_size = platform.get_window_size(platform_state.window);
        if game_state.window_size.x > game_state.window_size.y {
            game_state.rendering_scale = i32(f32(game_state.window_size.y) / f32(NATIVE_RESOLUTION.y));
        } else {
            game_state.rendering_scale = i32(f32(game_state.window_size.x) / f32(NATIVE_RESOLUTION.x));
        }
        renderer_state.display_dpi = renderer.get_display_dpi(platform_state.window);
        renderer_state.rendering_size = {
            NATIVE_RESOLUTION.x * game_state.rendering_scale,
            NATIVE_RESOLUTION.y * game_state.rendering_scale,
        };
        odd_offset : i32 = 0;
        if game_state.window_size.y % 2 == 1 {
            odd_offset = 1;
        }
        renderer_state.rendering_offset = {
            (game_state.window_size.x - renderer_state.rendering_size.x) / 2 + odd_offset,
            (game_state.window_size.y - renderer_state.rendering_size.y) / 2 + odd_offset,
        };
    }

    renderer.clear(CLEAR_COLOR);
    renderer.draw_fill_rect(&{ 0, 0, game_state.window_size.x, game_state.window_size.y }, VOID_COLOR);

    profiler.profiler_start("render.sort_entities");
    sorted_entities := slice.clone(game_state.entities.entities[:]);

    {
        context.user_ptr = rawptr(&game_state.entities.components_rendering);
        sort_entities_by_z_index :: proc(a: Entity, b: Entity) -> bool {
            components_rendering := cast(^map[Entity]Component_Rendering)context.user_ptr;
            return components_rendering[a].z_index <= components_rendering[b].z_index;
        }
        slice.sort_by(sorted_entities, sort_entities_by_z_index);
    }
    profiler.profiler_end("render.sort_entities");

    profiler.profiler_start("render.entities");
    pixel_per_cell := f32(PIXEL_PER_CELL);
    camera_position := game_state.entities.components_position[game_state.camera];

    for entity in sorted_entities {
        position_component, has_position := game_state.entities.components_position[entity];
        rendering_component, has_rendering := game_state.entities.components_rendering[entity];
        world_info_component, has_world_info := game_state.entities.components_world_info[entity];

        // if has_world_info == false || world_info_component.room_index != game_state.current_room_index {
        //     continue;
        // }

        if has_rendering && rendering_component.visible && has_position {
            source := renderer.Rect {
                rendering_component.texture_position.x, rendering_component.texture_position.y,
                rendering_component.texture_size.x, rendering_component.texture_size.y,
            };
            destination := renderer.Rectf32 {
                (position_component.world_position.x - camera_position.world_position.x) * pixel_per_cell,
                (position_component.world_position.y - camera_position.world_position.y) * pixel_per_cell,
                pixel_per_cell,
                pixel_per_cell,
            };
            renderer.draw_texture_by_index(rendering_component.texture_index, &source, &destination, f32(game_state.rendering_scale));
        }
    }
    profiler.profiler_end("render.entities");

    // Draw the letterboxes on top of the world
    if game_state.draw_letterbox {
        renderer.draw_fill_rect(&LETTERBOX_TOP, LETTERBOX_COLOR, f32(game_state.rendering_scale));
        renderer.draw_fill_rect(&LETTERBOX_BOTTOM, LETTERBOX_COLOR, f32(game_state.rendering_scale));
        renderer.draw_fill_rect(&LETTERBOX_LEFT, LETTERBOX_COLOR, f32(game_state.rendering_scale));
        renderer.draw_fill_rect(&LETTERBOX_RIGHT, LETTERBOX_COLOR, f32(game_state.rendering_scale));
    }

    ui.process_ui_commands();

    profiler.profiler_start("render.window_border");
    renderer.draw_window_border(game_state.window_size, WINDOW_BORDER_COLOR);
    profiler.profiler_end("render.window_border");

    profiler.profiler_start("render.present");
    renderer.present();
    profiler.profiler_end("render.present");

    profiler.profiler_end("render");

    // profiler.profiler_print_all();
}
