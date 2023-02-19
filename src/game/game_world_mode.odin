package game

import "core:fmt"
import "core:log"
import "core:mem"
import "core:runtime"
import "core:strconv"
import "core:strings"

import platform "../engine/platform"
import renderer "../engine/renderer"
import engine_math "../engine/math"
import ldtk "../engine/ldtk"
import ui "../engine/renderer/ui"

Game_Mode_World :: struct {
    initialized:            bool,
    world_mode:             World_Mode,
    world_mode_arena:       mem.Arena,
    world_mode_allocator:   mem.Allocator,
    world_mode_data:        ^World_Mode_Data,

    // TODO: Rename world to level
    // TODO: Don't store ldtk data into world/level, only game logic stuff
    world_entities:         [dynamic]Entity,
    world:                  World,
    room_next_index:        i32,
    mouse_cursor:           Entity,
}

World_Mode :: enum {
    Explore,
    RoomTransition,
    Battle,
}

World_Mode_Data :: union {
    World_Mode_Explore,
    World_Mode_RoomTransition,
    World_Mode_Battle,
}
World_Mode_Explore :: struct { }
World_Mode_RoomTransition :: struct { }

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
    tileset_uid:        i32,
}

Battle_Mode :: enum {
    None,
    Wait_For_Charge,
    Start_Turn,
    Ended,
}

world_mode_update :: proc(
    game_state: ^Game_State,
    platform_state: ^platform.Platform_State,
    renderer_state: ^renderer.Renderer_State,
    delta_time: f64,
) {
    world_data := cast(^Game_Mode_World) game_state.game_mode_data;

    if world_data.initialized == false {
        world_data.world_mode_allocator = platform.make_arena_allocator(.WorldMode, WORLD_MODE_ARENA_SIZE, &world_data.world_mode_arena, game_state.game_mode_allocator);

        game_state.draw_letterbox = true;
        world_size := Vector2i { 3, 3 };

        {
            entity := entity_make("Camera", &game_state.entities);
            room_position := engine_math.grid_index_to_position(i32(game_state.current_room_index), world_size.x);
            world_position := Vector2f32 {
                f32(room_position.x * ROOM_SIZE.x) - 40.0 / f32(PIXEL_PER_CELL),
                f32(room_position.y * ROOM_SIZE.y) - 18.0 / f32(PIXEL_PER_CELL),
            };
            game_state.entities.components_position[entity] = Component_Position {};
            (&game_state.entities.components_position[entity]).world_position = world_position;
            game_state.camera = entity;
        }

        ldtk, ok := ldtk.load_file(ROOMS_PATH, context.temp_allocator);
        log.infof("Level %v loaded: %s (%s)", ROOMS_PATH, ldtk.iid, ldtk.jsonVersion);

        for tileset in ldtk.defs.tilesets {
            rel_path, value_ok := tileset.relPath.?;
            if value_ok == false {
                continue;
            }

            path, path_ok := strings.replace(rel_path, "../art", "media/art", 1);
            if path_ok == false {
                log.warnf("Invalid tileset: %s", rel_path);
                continue;
            }

            key := tileset_ui_to_texture_key(tileset.uid);
            game_state.textures[key], _, _ = load_texture(path);
        }

        world_data.world = make_world(
            world_size,
            {
                6, 2, 7,
                5, 1, 3,
                9, 4, 8,
            },
            &ldtk,
            game_state.game_mode_allocator,
        );
        world_data.world_entities = make_world_entities(game_state, &world_data.world, game_state.game_mode_allocator);

        for entity in game_state.party {
            entity_set_visibility(entity, true, &game_state.entities);
        }

        {
            entity := entity_make("Mouse cursor", &game_state.entities);
            game_state.entities.components_position[entity] = entity_make_component_position({ 0, 0 });
            // game_state.entities.components_world_info[entity] = Component_World_Info { game_state.current_room_index };
            game_state.entities.components_rendering[entity] = Component_Rendering {
                true, 99, game_state.textures["placeholder_0"],
                { 0, 0 }, { 32, 32 },
            };
            world_data.mouse_cursor = entity;
        }

        world_data.initialized = true;
    }

    room := &world_data.world.rooms[game_state.current_room_index];
    leader := game_state.party[0];
    leader_position := &game_state.entities.components_position[leader];
    camera_position := &game_state.entities.components_position[game_state.camera];

    { // Update mouse position
        game_state.mouse_grid_position = screen_position_to_global_position(game_state.mouse_screen_position, room, renderer_state.rendering_offset, game_state.rendering_scale);
        entity_move_instant(world_data.mouse_cursor, game_state.mouse_grid_position, &game_state.entities);
    }

    switch world_data.world_mode {
        case .Explore: {
            explore_data := cast(^World_Mode_Explore) world_data.world_mode_data;

            if platform.contains_os_args("test-battle") {
                move_leader_to(leader, { 22, 9 }, game_state, world_data);
                return;
            }

            if platform_state.mouse_keys[platform.BUTTON_LEFT].released && ui.is_hovered() == false {
                move_leader_to(leader, game_state.mouse_grid_position, game_state, world_data);
            }

            if platform_state.keys[.F10].released { // Back to title
                for entity in game_state.party {
                    entity_delete(entity, &game_state.entities);
                }
                for entity in world_data.world_entities {
                    entity_delete(entity, &game_state.entities);
                }
                clear(&game_state.party);
                set_game_mode(game_state, .Title, Game_Mode_Title);
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
                    entity_move_grid(leader_position, leader_position.grid_position + move_input);
                }
            }
        }

        case .RoomTransition: {
            if camera_position.move_t >= 1 {
                game_state.current_room_index = world_data.room_next_index;

                for entity in game_state.party {
                    (&game_state.entities.components_world_info[entity]).room_index = game_state.current_room_index;
                }

                room = &world_data.world.rooms[game_state.current_room_index];
                leader_destination := room_position_to_global_position({ 7, 4 }, room);
                entity_move_instant(leader, leader_destination, &game_state.entities);

                has_foe := false;
                for entity, component_world_info in game_state.entities.components_world_info {
                    if component_world_info.room_index == game_state.current_room_index {
                        component_flag, has_flag := game_state.entities.components_flag[entity];
                        if has_flag && .Foe in component_flag.value {
                            has_foe = true;
                        }
                    }
                }

                if has_foe {
                    set_world_mode(world_data, .Battle, World_Mode_Battle);
                } else {
                    set_world_mode(world_data, .Explore, World_Mode_Explore);
                }
            }
        }

        case .Battle: {
            battle_mode_update(game_state, platform_state, world_data);
        }
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
        room_position := engine_math.grid_index_to_position(i32(room_index), world.size.x);

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

        tileset_uid : i32 = 0;
        for tileset in data.defs.tilesets {
            if tileset.uid == grid_layer.tilesetDefUid {
                tileset_uid = tileset.uid
                break;
            }
        }

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
            index := engine_math.grid_position_to_index(position, ROOM_SIZE.x);
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

        world.rooms[room_index] = Room { room_id, room_position, room_size, grid, tiles, entity_instances, tileset_uid };
    }
    return world;
}

make_world_entities :: proc(game_state: ^Game_State, world: ^World, allocator: runtime.Allocator) -> [dynamic]Entity {
    world_entities := make([dynamic]Entity, allocator);

    for room, room_index in world.rooms {
        room_position := engine_math.grid_index_to_position(i32(room_index), world.size.x);

        // Grid
        for cell_value, cell_index in room.grid {
            cell_room_position := engine_math.grid_index_to_position(i32(cell_index), room.size.x);
            grid_position := room_position * room.size + cell_room_position;
            tile, tile_exists := room.tiles[cell_index];
            source_position := Vector2i { tile.src[0], tile.src[1] };

            entity := entity_make(strings.clone(fmt.tprintf("Tile %v", grid_position)), &game_state.entities);
            game_state.entities.components_position[entity] = entity_make_component_position(grid_position);
            game_state.entities.components_world_info[entity] = Component_World_Info { i32(room_index) };
            game_state.entities.components_rendering[entity] = Component_Rendering {
                true, 0, game_state.textures[tileset_ui_to_texture_key(room.tileset_uid)],
                source_position, { SPRITE_GRID_SIZE, SPRITE_GRID_SIZE },
            };
            game_state.entities.components_flag[entity] = Component_Flag { { .Tile } };

            append(&world_entities, entity);
        }

        // Entities
        for entity_instance in room.entity_instances {
            entity_def := world.entities[entity_instance.defUid];
            entity := entity_make(strings.clone(entity_def.identifier), &game_state.entities);

            source_position: Vector2i;
            switch entity_def.identifier {
                case "Door": {
                    source_position = { 32, 0 };
                    direction: Vector2i;
                    switch entity_instance.__grid {
                        case { 14, 4 }:
                            direction = { +1, 0 };
                        case { 0, 4 }:
                            direction = { -1, 0 };
                        case { 7, 0 }:
                            direction = { 0, -1 };
                        case { 7, 8 }:
                            direction = { 0, +1 };
                    }
                    game_state.entities.components_flag[entity] = Component_Flag { { .Interactive } };
                    game_state.entities.components_door[entity] = Component_Door { direction };
                }
                case "Foe": {
                    // TODO: use foe.id
                    source_position = { 64, 0 };
                    game_state.entities.components_flag[entity] = Component_Flag { { .Unit, .Foe } };
                }
                case "Event": {
                    source_position = { 96, 0 };
                    game_state.entities.components_flag[entity] = Component_Flag { { .Interactive } };
                }
            }

            grid_position : Vector2i = {
                room_position.x * ROOM_SIZE.x + entity_instance.__grid.x,
                room_position.y * ROOM_SIZE.y + entity_instance.__grid.y,
            };
            game_state.entities.components_position[entity] = entity_make_component_position(grid_position);
            game_state.entities.components_world_info[entity] = Component_World_Info { i32(room_index) };
            game_state.entities.components_rendering[entity] = Component_Rendering {
                true, 1, game_state.textures["placeholder_0"],
                source_position, { 32, 32 },
            };

            append(&world_entities, entity);
        }
    }

    // log.debugf("world_entities: %v", world_entities);

    return world_entities;
}

room_position_to_global_position :: proc(room_position: Vector2i, room: ^Room) -> Vector2i {
    return {
        (room.position.x * room.size.x) + room_position.x,
        (room.position.y * room.size.y) + room_position.y,
    };
}

screen_position_to_global_position :: proc(screen_position: Vector2i, room: ^Room, rendering_offset: Vector2i, rendering_scale: i32) -> Vector2i {
    room_base := Vector2i {
        room.position.x * room.size.x,
        room.position.y * room.size.y,
    };
    cell_position := Vector2i {
        i32(f32(screen_position.x - rendering_offset.x - LETTERBOX_SIZE.x * rendering_scale) / f32(PIXEL_PER_CELL * rendering_scale)),
        i32(f32(screen_position.y - rendering_offset.y - LETTERBOX_SIZE.y * rendering_scale) / f32(PIXEL_PER_CELL * rendering_scale)),
    };
    return room_base + cell_position;
}

set_world_mode :: proc(world_data: ^Game_Mode_World, mode: World_Mode, $data_type: typeid) {
    log.debugf("world_mode changed %v -> %v", world_data.world_mode, mode);
    free_all(world_data.world_mode_allocator);
    world_data.world_mode = mode;
    world_data.world_mode_data = cast(^World_Mode_Data) new(data_type, world_data.world_mode_allocator);
}

set_battle_mode :: proc(battle_data: ^World_Mode_Battle, mode: Battle_Mode) {
    log.debugf("battle_mode changed %v -> %v", battle_data.battle_mode, mode);
    battle_data.battle_mode = mode;
    battle_data.battle_mode_initialized = false;
}

move_leader_to :: proc(leader: Entity, destination: Vector2i, game_state: ^Game_State, world_data: ^Game_Mode_World) {
    camera_position := &game_state.entities.components_position[game_state.camera];

    // TODO: move tile to tile with A* pathfinding
    entity_move_instant(leader, destination, &game_state.entities);

    entity_at_position, found := entity_get_first_at_position(destination, .Interactive, &game_state.entities);
    if found {
        log.debugf("Entity found: %v", entity_format(entity_at_position, &game_state.entities));
        component_door, has_door := game_state.entities.components_door[entity_at_position];
        if has_door {
            destination := camera_position.world_position + Vector2f32(array_cast(component_door.direction * ROOM_SIZE, f32));
            entity_move_world(camera_position, destination, 3.0);

            current_room_position := engine_math.grid_index_to_position(game_state.current_room_index, world_data.world.size.x);
            next_room_position := current_room_position + component_door.direction;
            world_data.room_next_index = engine_math.grid_position_to_index(next_room_position, world_data.world.size.x);

            set_world_mode(world_data, .RoomTransition, World_Mode_RoomTransition);
        }
    }
}

tileset_ui_to_texture_key :: proc(tileset_uid: i32) -> string {
    return strings.clone(fmt.tprintf("tileset_%v", tileset_uid));
}
