package game

import "core:fmt"
import "core:log"
import "core:math/linalg"
import "core:runtime"
import "core:strconv"
import "core:strings"

import platform "../engine/platform"
import renderer "../engine/renderer"
import ui "../engine/renderer/ui"
import logger "../engine/logger"
import math "../engine/math"
import ldtk "../engine/ldtk"

World_Mode :: struct {
    initialized:        bool,
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

        // TODO: Move this to game_state.world_mode.world?
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
        for room, room_index in game_state.world.rooms {
            room_position := math.grid_index_to_position(i32(room_index), game_state.world.size.x);

            for entity_instance in room.entities {
                entity_def := game_state.world.entities[entity_instance.defUid];
                entity := make_entity(game_state, entity_def.identifier);
                grid_position : math.Vector2i = {
                    room_position.x * ROOM_SIZE.x + entity_instance.__grid.x,
                    room_position.y * ROOM_SIZE.y + entity_instance.__grid.y,
                };
                world_position := Vector2f32(array_cast(grid_position, f32));
                game_state.components_position[entity] = Component_Position {
                    grid_position, world_position,
                    world_position, world_position,
                    0, 0,
                };
                game_state.components_rendering[entity] = Component_Rendering {
                    true, game_state.textures["placeholder_0"],
                    { 0, 0 }, { 32, 32 },
                };
            }
        }

        // TODO: Calculate this from the start room position
        game_state.camera_position = {
            f32(ROOM_SIZE.x * PIXEL_PER_CELL) - 40,
            f32(ROOM_SIZE.y * PIXEL_PER_CELL) - 18,
        };
        world_mode.camera_destination = game_state.camera_position;
        game_state.camera_zoom = 1;

        {
            unit := make_entity(game_state, "Ramza");
            position := Vector2i { ROOM_SIZE.x + 7, ROOM_SIZE.y + 4 };
            world_position := Vector2f32(array_cast(position, f32));
            game_state.components_position[unit] = Component_Position {
                position, world_position,
                world_position, world_position,
                0, 0,
            };
            game_state.components_rendering[unit] = Component_Rendering {
                false, game_state.textures["sage"],
                { 0, 0 }, { 48, 48 },
            };
            // game_state.components_animation[unit] = Component_Animation {
            //     0, 1.5, +1, false,
            //     0, { { 0 * 48, 0 }, { 1 * 48, 0 }, { 2 * 48, 0 }, { 3 * 48, 0 }, { 4 * 48, 0 }, { 5 * 48, 0 }, { 6 * 48, 0 }, { 7 * 48, 0 } },
            // };
            add_to_party(game_state, unit);
        }

        {
            unit := make_entity(game_state, "Delita");
            position := Vector2i { ROOM_SIZE.x + 6, ROOM_SIZE.y + 4 };
            world_position := Vector2f32(array_cast(position, f32));
            game_state.components_position[unit] = Component_Position {
                position, world_position,
                world_position, world_position,
                0, 0,
            };
            game_state.components_rendering[unit] = Component_Rendering {
                false, game_state.textures["jurons"],
                { 0, 0 }, { 48, 48 },
            };
            // game_state.components_animation[unit] = Component_Animation {
            //     0, 1.5, +1, false,
            //     0, { { 0 * 48, 0 }, { 1 * 48, 0 }, { 2 * 48, 0 }, { 3 * 48, 0 }, { 4 * 48, 0 }, { 5 * 48, 0 }, { 6 * 48, 0 }, { 7 * 48, 0 } },
            // };
            add_to_party(game_state, unit);
        }

        for entity in game_state.party {
            make_entity_visible(game_state, entity);
        }

        game_state.world_mode.initialized = true;
    }

    leader := game_state.party[0];
    leader_position := &game_state.components_position[leader];

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
            move_entity(leader_position, leader_position.grid_position + move_input);
        }

        if move_camera_input.x != 0 || move_camera_input.y != 0 {
            moving := game_state.camera_position != world_mode.camera_destination;
            if moving == false {
                using linalg;
                world_mode.camera_origin = game_state.camera_position;
                world_mode.camera_destination = game_state.camera_position + Vector2f32(array_cast(move_camera_input * ROOM_SIZE * PIXEL_PER_CELL, f32));
                world_mode.camera_move_t = 0.0;
                world_mode.camera_move_speed = 3.0;
            }
        }
    }

    if game_state.camera_position != world_mode.camera_destination {
        world_mode.camera_move_t = clamp(world_mode.camera_move_t + f32(delta_time) * world_mode.camera_move_speed, 0, 1);
        game_state.camera_position = linalg.lerp(world_mode.camera_origin, world_mode.camera_destination, world_mode.camera_move_t);
    }
}

make_world :: proc(
    world_size: math.Vector2i, room_ids: []i32, data: ^ldtk.LDTK,
    allocator: runtime.Allocator = context.allocator,
) -> World {
    context.allocator = allocator;

    rooms := make([]Room, world_size.x * world_size.y);
    world := World {};
    world.size = math.Vector2i { world_size.x, world_size.y };
    world.rooms = rooms;

    // Entities
    entities := make(map[i32]ldtk.Entity, len(data.defs.entities));
    for entity in data.defs.entities {
        entities[entity.uid] = entity;
    }
    world.entities = entities;

    for room_index := 0; room_index < len(room_ids); room_index += 1 {
        id := room_ids[room_index];

        level_index := -1;
        for level, i in data.levels {
            parts := strings.split(level.identifier, ROOM_PREFIX);
            if len(parts) > 0 {
                parsed_id, ok := strconv.parse_int(parts[1]);
                if ok && i32(parsed_id) == id {
                    level_index = i;
                    break;
                }
            }
        }
        assert(level_index > -1, fmt.tprintf("Can't find level with identifier: %v%v", ROOM_PREFIX, id));
        level := data.levels[level_index];

        // IntGrid
        grid_layer_instance := level.layerInstances[LDTK_GRID_LAYER];
        grid_layer_index := -1;
        for layer, i in data.defs.layers {
            if layer.uid == grid_layer_instance.layerDefUid {
                grid_layer_index = i;
                break;
            }
        }
        assert(grid_layer_index > -1, fmt.tprintf("Can't find layer with uid: %v", grid_layer_instance.layerDefUid));
        grid_layer := data.defs.layers[grid_layer_index];

        // room_size := math.Vector2i {
        //     level.pxWid / grid_layer.gridSize,
        //     level.pxHei / grid_layer.gridSize,
        // };

        grid := [ROOM_LEN]i32 {};
        for value, i in grid_layer_instance.intGridCsv {
            grid[i] = value;
        }

        tiles := make(map[int]ldtk.Tile, len(grid_layer_instance.autoLayerTiles));
        for tile in grid_layer_instance.autoLayerTiles {
            position := math.Vector2i {
                tile.px.x / grid_layer.gridSize,
                tile.px.y / grid_layer.gridSize,
            };
            index := math.grid_position_to_index(position, ROOM_SIZE.x);
            tiles[int(index)] = tile;
        }

        // Entity instances
        entity_layer_instance := level.layerInstances[LDTK_ENTITY_LAYER];
        entity_layer_index := -1;
        for layer, i in data.defs.layers {
            if layer.uid == entity_layer_instance.layerDefUid {
                entity_layer_index = i;
                break;
            }
        }
        assert(entity_layer_index > -1, fmt.tprintf("Can't find layer with uid: %v", entity_layer_instance.layerDefUid));
        // entity_layer := data.defs.layers[entity_layer_index];

        entity_instances := make([]ldtk.EntityInstance, len(entity_layer_instance.entityInstances));
        for entity_instance, index in entity_layer_instance.entityInstances {
            // position := math.Vector2i {
            //     tile.px.x / entity_layer.gridSize,
            //     tile.px.y / entity_layer.gridSize,
            // };
            entity_instances[int(index)] = entity_instance;
        }

        world.rooms[room_index] = Room { id, ROOM_SIZE, grid, tiles, entity_instances };
    }
    return world;
}

move_entity :: proc(position_component: ^Component_Position, destination: Vector2i) {
    position_component.world_position = Vector2f32(array_cast(position_component.world_position, f32));
    position_component.move_origin = position_component.world_position;
    position_component.move_destination = Vector2f32(array_cast(destination, f32));
    position_component.grid_position = destination;
    position_component.move_t = 0;
    position_component.move_speed = 3.0;
}
