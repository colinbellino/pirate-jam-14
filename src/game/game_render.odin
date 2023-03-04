package game

import "core:runtime"
import "core:slice"
import "core:log"
import "core:time"
import "core:sort"

import "../engine/platform"
import "../engine/renderer"
import "../engine/renderer/ui"
import "../engine/logger"
import "../engine/profiler"
import "../debug"

@(export)
game_render : Game_Render_Proc : proc(
    arena_allocator: runtime.Allocator,
    delta_time: f64,
    game_state: ^Game_State,
    platform_state: ^platform.Platform_State,
    renderer_state: ^renderer.Renderer_State,
    logger_state: ^logger.Logger_State,
    ui_state: ^ui.UI_State,
) {
    if platform_state.window_resized {
        game_state.window_size = platform.get_window_size(platform_state.window);
        if game_state.window_size.x > game_state.window_size.y {
            game_state.rendering_scale = i32(f32(game_state.window_size.y) / f32(NATIVE_RESOLUTION.y));
        } else {
            game_state.rendering_scale = i32(f32(game_state.window_size.x) / f32(NATIVE_RESOLUTION.x));
        }
        renderer_state.display_dpi = renderer.get_display_dpi(renderer_state, platform_state.window);
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

    renderer.clear(renderer_state, CLEAR_COLOR);
    renderer.draw_fill_rect(renderer_state, &{ 0, 0, game_state.window_size.x, game_state.window_size.y }, VOID_COLOR);

    camera_position := game_state.entities.components_position[game_state.camera];

    debug.timed_block_begin("sort_entities");
    // TODO: This is kind of expensive to do each frame.
    // Either filter the entities before the sort or don't do this every single frame.
    sorted_entities := slice.clone(game_state.entities.entities[:], context.temp_allocator);
    {
        context.user_ptr = rawptr(&game_state.entities.components_z_index);
        sort_entities_by_z_index :: proc(a, b: Entity) -> int {
            components_z_index := cast(^map[Entity]Component_Z_Index)context.user_ptr;
            return int(components_z_index[a].z_index - components_z_index[b].z_index);
        }
        sort.heap_sort_proc(sorted_entities, sort_entities_by_z_index);
    }
    debug.timed_block_end("sort_entities");

    debug.timed_block_begin("draw_entities");
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
                (position_component.world_position.x - camera_position.world_position.x) * f32(PIXEL_PER_CELL),
                (position_component.world_position.y - camera_position.world_position.y) * f32(PIXEL_PER_CELL),
                f32(PIXEL_PER_CELL),
                f32(PIXEL_PER_CELL),
            };
            renderer.draw_texture_by_index(renderer_state, rendering_component.texture_index, &source, &destination, f32(game_state.rendering_scale));
        }
    }
    debug.timed_block_end("draw_entities");

    debug.timed_block_begin("draw_letterbox");
    // Draw the letterboxes on top of the world
    if game_state.draw_letterbox {
        renderer.draw_fill_rect(renderer_state, &LETTERBOX_TOP, LETTERBOX_COLOR, f32(game_state.rendering_scale));
        renderer.draw_fill_rect(renderer_state, &LETTERBOX_BOTTOM, LETTERBOX_COLOR, f32(game_state.rendering_scale));
        renderer.draw_fill_rect(renderer_state, &LETTERBOX_LEFT, LETTERBOX_COLOR, f32(game_state.rendering_scale));
        renderer.draw_fill_rect(renderer_state, &LETTERBOX_RIGHT, LETTERBOX_COLOR, f32(game_state.rendering_scale));
    }
    renderer.draw_window_border(renderer_state, game_state.window_size, WINDOW_BORDER_COLOR);
    debug.timed_block_end("draw_letterbox");

    // debug.timed_block_begin("ui.process_commands");
    // ui.process_commands(renderer_state);
    // debug.timed_block_end("ui.process_commands");

    {
        debug.timed_block("renderer.present");
        renderer.present(renderer_state);
    }

    // profiler.profiler_print_all();
}
