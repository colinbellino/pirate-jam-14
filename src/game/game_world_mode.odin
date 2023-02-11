package game

import "core:fmt"
import "core:log"
import "core:math"
import "core:math/linalg"
import "core:runtime"
import "core:strconv"
import "core:strings"

import platform "../engine/platform"
import renderer "../engine/renderer"
import ui "../engine/renderer/ui"
import logger "../engine/logger"
import emath "../engine/math"
import ldtk "../engine/ldtk"

World_Data :: struct {
    initialized:        bool,
    camera_move_t:      f32,
    camera_move_speed:  f32,
    camera_origin:      linalg.Vector2f32,
    camera_destination: linalg.Vector2f32,
    ldtk:               ldtk.LDTK,
    world:              World,
    world_entities:     [dynamic]Entity,
    mouse_cursor:       Entity,
    battle_entities:    [dynamic]Entity,
    battle_mode:        Battle_Mode,
}

World :: struct {
    size:               Vector2i,
    entities:           map[i32]ldtk.Entity,
    rooms:              []Room,
}

Room :: struct {
    id:                 i32,
    position:           Vector2i,
    size:               Vector2i,
    grid:               [ROOM_LEN]i32,
    tiles:              map[int]ldtk.Tile,
    entity_instances:   []ldtk.EntityInstance,
}

Battle_Mode :: enum {
    None,
    Started,
    Ended,
}

world_mode_fixed_update :: proc(
    game_state: ^Game_State,
    platform_state: ^platform.Platform_State,
    renderer_state: ^renderer.Renderer_State,
    logger_state: ^logger.Logger_State,
    ui_state: ^ui.UI_State,
    delta_time: f64,
) {
    world_data := cast(^World_Data) game_state.game_mode_data;

    if world_data.initialized == false {
        game_state.draw_letterbox = true;

        ldtk, ok := ldtk.load_file(ROOMS_PATH, game_state.game_mode_allocator);
        log.infof("Level %v loaded: %s (%s)", ROOMS_PATH, ldtk.iid, ldtk.jsonVersion);
        world_data.ldtk = ldtk;

        world_data.world = make_world(
            { 3, 3 },
            {
                6, 2, 7,
                5, 1, 3,
                9, 4, 8,
            },
            &world_data.ldtk,
            game_state.game_mode_allocator,
        );
        world_data.world_entities = make_world_entities(game_state, &world_data.world, game_state.game_mode_allocator);

        {
            room_position := emath.grid_index_to_position(i32(game_state.current_room_index), world_data.world.size.x);
            game_state.camera_position = {
                f32(room_position.x * ROOM_SIZE.x * PIXEL_PER_CELL) - 40,
                f32(room_position.y * ROOM_SIZE.y * PIXEL_PER_CELL) - 18,
            };
            world_data.camera_destination = game_state.camera_position;
            game_state.camera_zoom = 1;
        }

        for entity in game_state.party {
            entity_set_visibility(game_state, entity, true);
        }

        {
            entity := entity_make(game_state, "Mouse cursor");
            game_state.components_position[entity] = entity_make_component_position({ 0, 0 });
            game_state.components_world_info[entity] = Component_World_Info { game_state.current_room_index };
            game_state.components_rendering[entity] = Component_Rendering {
                true, game_state.textures["placeholder_0"],
                { 0, 0 }, { 32, 32 },
            };
            world_data.mouse_cursor = entity;
        }

        world_data.initialized = true;
    }

    leader := game_state.party[0];
    leader_position := &game_state.components_position[leader];

    {
        room := &world_data.world.rooms[game_state.current_room_index];
        mouse_room_position := screen_position_to_room_position(game_state.mouse_screen_position, renderer_state.rendering_offset, game_state.rendering_scale);
        game_state.mouse_grid_position = room_position_to_grid_position(mouse_room_position, room, game_state.rendering_scale);
        entity_move_instant(&game_state.components_position[world_data.mouse_cursor], game_state.mouse_grid_position);
    }

    if platform_state.keys[.F10].released {
        for entity in game_state.party {
            entity_delete(game_state, entity);
        }
        for entity in world_data.world_entities {
            entity_delete(game_state, entity);
        }
        clear(&game_state.party);
        set_game_mode(game_state, .Title, Title_Data);
    }

    {
        move_input := Vector2i {};
        if (platform_state.keys[.UP].released) {
            move_input.y -= 1;
        } else if (platform_state.keys[.DOWN].released) {
            move_input.y += 1;
        } else if (platform_state.keys[.LEFT].released) {
            move_input.x -= 1;
        } else if (platform_state.keys[.RIGHT].released) {
            move_input.x += 1;
        }
        if move_input.x != 0 ||  move_input.y != 0 {
            entity_move(leader_position, leader_position.grid_position + move_input);
        }

        move_camera_input := Vector2i {};
        if (platform_state.keys[.Z].released) {
            move_camera_input.y -= 1;
        } else if (platform_state.keys[.S].released) {
            move_camera_input.y += 1;
        } else if (platform_state.keys[.Q].released) {
            move_camera_input.x -= 1;
        } else if (platform_state.keys[.D].released) {
            move_camera_input.x += 1;
        }
        if move_camera_input.x != 0 || move_camera_input.y != 0 {
            moving := game_state.camera_position != world_data.camera_destination;
            if moving == false {
                destination := game_state.camera_position + Vector2f32(array_cast(move_camera_input * ROOM_SIZE * PIXEL_PER_CELL, f32));
                move_camera_over_time(world_data, game_state.camera_position, destination);

                current_room_position := emath.grid_index_to_position(game_state.current_room_index, world_data.world.size.x);
                next_room_position := current_room_position + move_camera_input;
                game_state.current_room_index = emath.grid_position_to_index(next_room_position, world_data.world.size.x);

                for entity in game_state.party {
                    (&game_state.components_world_info[entity]).room_index = game_state.current_room_index;
                }
            }
        }

        move_camera_over_time :: proc(world_data: ^World_Data, start_position: Vector2f32, destination: Vector2f32) {
            using linalg;
            world_data.camera_origin = start_position;
            world_data.camera_destination = destination;
            world_data.camera_move_t = 0.0;
            world_data.camera_move_speed = 3.0;
        }
    }

    if game_state.camera_position != world_data.camera_destination {
        world_data.camera_move_t = clamp(world_data.camera_move_t + f32(delta_time) * world_data.camera_move_speed, 0, 1);
        game_state.camera_position = linalg.lerp(world_data.camera_origin, world_data.camera_destination, world_data.camera_move_t);
    }
}

make_world :: proc(
    world_size: Vector2i, room_ids: []i32, data: ^ldtk.LDTK,
    allocator: runtime.Allocator = context.allocator,
) -> World {
    context.allocator = allocator;

    rooms := make([]Room, world_size.x * world_size.y);
    world := World {};
    world.size = Vector2i { world_size.x, world_size.y };
    world.rooms = rooms;

    // Entities
    entities := make(map[i32]ldtk.Entity, len(data.defs.entities));
    for entity in data.defs.entities {
        entities[entity.uid] = entity;
    }
    world.entities = entities;

    for room_index := 0; room_index < len(room_ids); room_index += 1 {
        room_id := room_ids[room_index];
        room_position := emath.grid_index_to_position(i32(room_index), world.size.x);
        log.debugf("room_position: %v", room_position);

        level_index := -1;
        for level, i in data.levels {
            parts := strings.split(level.identifier, ROOM_PREFIX);
            if len(parts) > 0 {
                parsed_id, ok := strconv.parse_int(parts[1]);
                if ok && i32(parsed_id) == room_id {
                    level_index = i;
                    break;
                }
            }
        }
        assert(level_index > -1, fmt.tprintf("Can't find level with identifier: %v%v", ROOM_PREFIX, room_id));
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

        room_size := Vector2i {
            level.pxWid / grid_layer.gridSize,
            level.pxHei / grid_layer.gridSize,
        };

        grid := [ROOM_LEN]i32 {};
        for value, i in grid_layer_instance.intGridCsv {
            grid[i] = value;
        }

        tiles := make(map[int]ldtk.Tile, len(grid_layer_instance.autoLayerTiles));
        for tile in grid_layer_instance.autoLayerTiles {
            position := Vector2i {
                tile.px.x / grid_layer.gridSize,
                tile.px.y / grid_layer.gridSize,
            };
            index := emath.grid_position_to_index(position, ROOM_SIZE.x);
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
            entity_instances[int(index)] = entity_instance;
        }

        world.rooms[room_index] = Room { room_id, room_position, room_size, grid, tiles, entity_instances };
    }
    return world;
}

make_world_entities :: proc(game_state: ^Game_State, world: ^World, allocator: runtime.Allocator) -> [dynamic]Entity {
    world_entities := make([dynamic]Entity, allocator);

    for room, room_index in world.rooms {
        room_position := emath.grid_index_to_position(i32(room_index), world.size.x);

        // Grid
        for cell_value, cell_index in room.grid {
            cell_room_position := emath.grid_index_to_position(i32(cell_index), room.size.x);
            grid_position := room_position * room.size + cell_room_position;
            tile, tile_exists := room.tiles[cell_index];
            source_position := Vector2i { tile.src[0], tile.src[1] };

            if tile_exists == false {
                source_position = Vector2i {
                    PIXEL_PER_CELL * (3 + i32(cell_index % 2)),
                    80,
                };
            }

            entity := entity_make(game_state, strings.clone(fmt.tprintf("Tile %v", grid_position)));
            game_state.components_position[entity] = entity_make_component_position(grid_position);
            game_state.components_world_info[entity] = Component_World_Info { i32(room_index) };
            game_state.components_rendering[entity] = Component_Rendering {
                true, game_state.textures["room"],
                source_position, { SPRITE_GRID_SIZE, SPRITE_GRID_SIZE },
            };

            append(&world_entities, entity);
        }

        // Entities
        for entity_instance in room.entity_instances {
            entity_def := world.entities[entity_instance.defUid];
            entity := entity_make(game_state, entity_def.identifier);

            source_position := Vector2i { 0, 0 };
            switch entity_def.identifier {
                case "Door":
                    source_position = { 32, 0 };
                case "Battle":
                    source_position = { 64, 0 };
                case "Event":
                    source_position = { 96, 0 };
            }

            grid_position : Vector2i = {
                room_position.x * ROOM_SIZE.x + entity_instance.__grid.x,
                room_position.y * ROOM_SIZE.y + entity_instance.__grid.y,
            };
            game_state.components_position[entity] = entity_make_component_position(grid_position);
            game_state.components_world_info[entity] = Component_World_Info { i32(room_index) };
            game_state.components_rendering[entity] = Component_Rendering {
                true, game_state.textures["placeholder_0"],
                source_position, { 32, 32 },
            };

            append(&world_entities, entity);
        }
    }

    // log.debugf("world_entities: %v", world_entities);

    return world_entities;
}

start_battle :: proc(game_state: ^Game_State) {
    world_data := cast(^World_Data) game_state.game_mode_data;

    for entity, world_info in game_state.components_world_info {
        if world_info.room_index == game_state.current_room_index {
            append(&world_data.battle_entities, entity);
        }
    }

    log.debugf("start battle: %v", world_data.battle_entities);
    world_data.battle_mode = .Started;
}

room_position_to_grid_position :: proc(room_position: Vector2i, room: ^Room, rendering_scale: i32) -> Vector2i {
    return {
        room.position.x * room.size.x + i32(math.floor(f32(room_position.x) / f32(PIXEL_PER_CELL * rendering_scale))),
        room.position.y * room.size.y + i32(math.floor(f32(room_position.y) / f32(PIXEL_PER_CELL * rendering_scale))),
    };
}

screen_position_to_room_position :: proc(screen_position: Vector2i, rendering_offset: Vector2i, rendering_scale: i32) -> Vector2i {
    return {
        screen_position.x - rendering_offset.x - LETTERBOX_SIZE.x * rendering_scale,
        screen_position.y - rendering_offset.y - LETTERBOX_SIZE.y * rendering_scale,
    }
}
