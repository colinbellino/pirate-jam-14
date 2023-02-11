package game

import "core:log"
import "core:math/linalg"

import platform "../engine/platform"
import renderer "../engine/renderer"
import ui "../engine/renderer/ui"
import logger "../engine/logger"
import math "../engine/math"
import ldtk "../engine/ldtk"

World_Mode :: struct {
    initialized:        bool,
    camera_moving:      bool,
    camera_move_t:      f32,
    camera_move_speed:  f32,
    camera_origin:      linalg.Vector2f32,
    camera_destination: linalg.Vector2f32,
}

world_mode_update :: proc(
    game_state: ^Game_State,
    platform_state: ^platform.Platform_State,
    renderer_state: ^renderer.Renderer_State,
    logger_state: ^logger.Logger_State,
    ui_state: ^ui.UI_State,
    delta_time: f64,
) {
    world_mode := game_state.world_mode;

    if game_state.world_mode.initialized == false {
        game_state.draw_letterbox = true;

        ldtk, ok := ldtk.load_file(ROOMS_PATH, game_state.game_mode_allocator);
        log.infof("Level %v loaded: %s (%s)", ROOMS_PATH, ldtk.iid, ldtk.jsonVersion);
        game_state.ldtk = ldtk;

        // TODO: Move this to game_state.world_mode.world
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
        move_input := math.Vector2i {};
        if (platform_state.inputs[.UP].released) {
            move_input.y -= 1;
        } else if (platform_state.inputs[.DOWN].released) {
            move_input.y += 1;
        } else if (platform_state.inputs[.LEFT].released) {
            move_input.x -= 1;
        } else if (platform_state.inputs[.RIGHT].released) {
            move_input.x += 1;
        }

        move_camera_input := math.Vector2i {};
        if (platform_state.inputs[.Z].released) {
            move_camera_input.y -= 1;
        } else if (platform_state.inputs[.S].released) {
            move_camera_input.y += 1;
        } else if (platform_state.inputs[.Q].released) {
            move_camera_input.x -= 1;
        } else if (platform_state.inputs[.D].released) {
            move_camera_input.x += 1;
        }

        if move_input.x != 0 ||  move_input.y != 0 {
            leader_position.position += move_input;
            game_state.components_position[leader] = leader_position;
        }

        if move_camera_input.x != 0 || move_camera_input.y != 0 {
            if world_mode.camera_moving == false {
                using linalg;
                world_mode.camera_origin = game_state.camera_position;
                world_mode.camera_destination = game_state.camera_position + Vector2f32(array_cast(move_camera_input * ROOM_SIZE * PIXEL_PER_CELL, f32));
                world_mode.camera_moving = true;
                world_mode.camera_move_t = 0.0;
                world_mode.camera_move_speed = 3.0;
            }
        }
    }

    if world_mode.camera_moving {
        // log.debugf("world_mode.camera_move_t: %v", world_mode.camera_move_t);
        // log.debugf("game_state.camera_position: %v", game_state.camera_position);
        world_mode.camera_move_t = clamp(world_mode.camera_move_t + f32(delta_time) * world_mode.camera_move_speed, 0, 1);
        game_state.camera_position = linalg.lerp(world_mode.camera_origin, world_mode.camera_destination, world_mode.camera_move_t);
        if world_mode.camera_move_t == 1 {
            world_mode.camera_moving = false;
        }
    }
}
