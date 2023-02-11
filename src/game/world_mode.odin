package game

import "core:fmt"
import "core:log"
import "core:math/linalg"

import platform "../engine/platform"
import renderer "../engine/renderer"
import ui "../engine/renderer/ui"
import logger "../engine/logger"
import math "../engine/math"
import ldtk "../engine/ldtk"

world_mode_update_and_render :: proc(
    game_state: ^Game_State,
    platform_state: ^platform.State,
    renderer_state: ^renderer.State,
    logger_state: ^logger.State,
    ui_state: ^ui.State,
) {
    if game_state.world_mode.initialized == false {
        ldtk, ok := ldtk.load_file(ROOMS_PATH, game_state.game_mode_allocator);
        log.infof("Level %v loaded: %s (%s)", ROOMS_PATH, ldtk.iid, ldtk.jsonVersion);
        game_state.ldtk = ldtk;

        game_state.world = make_world(
            { 3, 3 },
            {
                6, 2, 7,
                5, 1, 3,
                9, 4, 8,
            },
            &game_state.ldtk,
            game_state.game_mode_allocator,
        );
        // log.debugf("LDTK: %v", game_state.ldtk);
        // log.debugf("World: %v", game_state.world);

        game_state.camera_position = { -40, -18 };
        game_state.camera_zoom = 1;

        unit_0 := make_entity(game_state, "Ramza");
        game_state.components_position[unit_0] = Component_Position { { 7, 4 } };
        game_state.components_rendering[unit_0] = Component_Rendering { false, game_state.texture_hero0 };
        unit_1 := make_entity(game_state, "Delita");
        game_state.components_position[unit_1] = Component_Position { { 6, 4 } };
        game_state.components_rendering[unit_1] = Component_Rendering { false, game_state.texture_hero1 };

        add_to_party(game_state, unit_0);
        // add_to_party(game_state, unit_1);

        for entity in game_state.party {
            make_entity_visible(game_state, entity);
        }

        game_state.world_mode.initialized = true;
    }

    leader := game_state.party[0];
    leader_position := game_state.components_position[leader];

    {
        using linalg;
        using math;

        move_input := Vector2i {};
        if (platform_state.inputs[.UP].released) {
            move_input.y -= 1;
        } else if (platform_state.inputs[.DOWN].released) {
            move_input.y += 1;
        } else if (platform_state.inputs[.LEFT].released) {
            move_input.x -= 1;
        } else if (platform_state.inputs[.RIGHT].released) {
            move_input.x += 1;
        }

        move_camera_input := Vector2i {};
        if (platform_state.inputs[.Z].released) {
            move_camera_input.y -= 1;
        } else if (platform_state.inputs[.S].released) {
            move_camera_input.y += 1;
        } else if (platform_state.inputs[.Q].released) {
            move_camera_input.x -= 1;
        } else if (platform_state.inputs[.D].released) {
            move_camera_input.x += 1;
        }

        if move_camera_input.x != 0 ||  move_camera_input.y != 0 {
            camera_destination := game_state.camera_position + Vector2f32(array_cast(move_camera_input * ROOM_SIZE * PIXEL_PER_CELL, f32));
            camera_origin := game_state.camera_position;
            game_state.camera_position = lerp(camera_origin, camera_destination, 1);
        }

        if move_input.x != 0 ||  move_input.y != 0 {
            leader_position.position += move_input;
            game_state.components_position[leader] = leader_position;
        }
    }

    for room, room_index in game_state.world.rooms {
        room_position := math.grid_index_to_position(i32(room_index), game_state.world.size.x);

        for cell_value, cell_index in room.grid {
            cell_position := math.grid_index_to_position(i32(cell_index), room.size.x);
            source_position := math.grid_index_to_position(cell_value, SPRITE_GRID_WIDTH);
            tile, ok := room.tiles[cell_index];
            if ok {
                cell_global_position := (room_position * room.size + cell_position);
                source_rect := renderer.Rect { tile.src[0], tile.src[1], SPRITE_GRID_SIZE, SPRITE_GRID_SIZE };
                destination_rect := renderer.Rect {
                    cell_global_position.x * PIXEL_PER_CELL - i32(game_state.camera_position.x),
                    cell_global_position.y * PIXEL_PER_CELL - i32(game_state.camera_position.y),
                    PIXEL_PER_CELL,
                    PIXEL_PER_CELL,
                };
                renderer.draw_texture_by_index(game_state.texture_room, &source_rect, &destination_rect, game_state.display_dpi, game_state.rendering_scale);
            }
        }
    }

    for entity in game_state.entities {
        position_component, has_position := game_state.components_position[entity];

        rendering_component, has_rendering := game_state.components_rendering[entity];
        if has_rendering && rendering_component.visible && has_position {
            destination_rect := renderer.Rect {
                position_component.position.x * PIXEL_PER_CELL - i32(game_state.camera_position.x),
                position_component.position.y * PIXEL_PER_CELL - i32(game_state.camera_position.y),
                PIXEL_PER_CELL,
                PIXEL_PER_CELL,
            };
            source_rect := renderer.Rect {
                0, 0,
                PLAYER_SPRITE_SIZE, PLAYER_SPRITE_SIZE,
            };
            renderer.draw_texture_by_index(rendering_component.texture, &source_rect, &destination_rect, game_state.display_dpi, game_state.rendering_scale);
        }
    }

    // Draw the letterboxes on top of the world
    {
        renderer.draw_fill_rect(&LETTERBOX_TOP, LETTERBOX_COLOR, game_state.display_dpi, game_state.rendering_scale);
        renderer.draw_fill_rect(&LETTERBOX_BOTTOM, LETTERBOX_COLOR, game_state.display_dpi, game_state.rendering_scale);
        renderer.draw_fill_rect(&LETTERBOX_LEFT, LETTERBOX_COLOR, game_state.display_dpi, game_state.rendering_scale);
        renderer.draw_fill_rect(&LETTERBOX_RIGHT, LETTERBOX_COLOR, game_state.display_dpi, game_state.rendering_scale);
    }
}
