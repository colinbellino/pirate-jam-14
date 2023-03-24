package game

import "core:fmt"
import "core:log"
import "core:runtime"
import "core:mem"
import "core:strings"

import "../engine"
import "../engine/ldtk"

WORLD_FILE_PATH         :: "./media/levels/world.ldtk";
LDTK_LAYER_ENTITIES     :: 0;
LDTK_LAYER_TILES        :: 1;
LDTK_LAYER_GRID         :: 2;

Game_Mode_World :: struct {
    initialized:            bool,
    world_mode:             World_Mode,
    world_mode_arena:       mem.Arena,
    world_mode_allocator:   mem.Allocator,
    world_mode_data:        ^World_Mode_Data,

    world_entities:         [dynamic]Entity,
    world_rooms:            []Room,
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

Room :: struct {
    id:                 i32,
    position:           Vector2i,
    size:               Vector2i,
    tileset_uid:        i32,
}

world_mode_update :: proc(
    game_state: ^Game_State,
    platform_state: ^engine.Platform_State,
    renderer_state: ^engine.Renderer_State,
    delta_time: f64,
) {
    world_data := cast(^Game_Mode_World) game_state.game_mode_data;

    if world_data.initialized == false {
        world_data.world_mode_allocator = engine.make_arena_allocator(.WorldMode, WORLD_MODE_ARENA_SIZE, &world_data.world_mode_arena, game_state.game_mode_allocator);
        context.allocator = world_data.world_mode_allocator;

        // game_state.draw_letterbox = true;
        game_state.draw_hud = true;

        ldtk, ok := ldtk.load_file(WORLD_FILE_PATH, context.temp_allocator);
        log.infof("Level %v loaded: %s (%s)", WORLD_FILE_PATH, ldtk.iid, ldtk.jsonVersion);

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

            key := tileset_uid_to_texture_key(tileset.uid, world_data.world_mode_allocator);
            game_state.textures[key], _, _ = load_texture(platform_state, renderer_state, path);
        }

        make_world(&ldtk, game_state, world_data);

        {
            entity := entity_make("Mouse cursor", &game_state.entities);
            game_state.entities.components_position[entity] = entity_make_component_position({ 0, 0 });
            // game_state.entities.components_world_info[entity] = Component_World_Info { game_state.current_room_index };
            game_state.entities.components_rendering[entity] = Component_Rendering {
                true, game_state.textures["placeholder_0"],
                { 32, 0 }, { 32, 32 },
            };
            game_state.entities.components_z_index[entity] = Component_Z_Index { 99 };
            world_data.mouse_cursor = entity;
        }

        {
            room := &world_data.world_rooms[game_state.current_room_index];
            entity := entity_make("Camera", &game_state.entities);
            world_position := Vector2f32 {
                f32(room.position.x * room.size.x) / f32(PIXEL_PER_CELL),
                f32(room.position.y * room.size.y) / f32(PIXEL_PER_CELL),
            };
            game_state.entities.components_position[entity] = Component_Position {};
            (&game_state.entities.components_position[entity]).world_position = world_position;
            game_state.camera = entity;
        }

        world_data.initialized = true;
    }

    room := &world_data.world_rooms[game_state.current_room_index];
    camera_position := &game_state.entities.components_position[game_state.camera];

    { // Update mouse position
        game_state.mouse_grid_position = screen_position_to_global_position(game_state.mouse_screen_position, room, renderer_state.rendering_offset, game_state.rendering_scale);
        entity_move_instant(world_data.mouse_cursor, game_state.mouse_grid_position, &game_state.entities);
    }

    switch world_data.world_mode {
        case .Explore: {
            explore_data := cast(^World_Mode_Explore) world_data.world_mode_data;

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
                    entity_move_grid(camera_position, camera_position.grid_position + move_input * room.size, 10.0);

                    // position_component.world_position += linalg.lerp(position_component.move_origin, position_component.move_destination, position_component.move_t);
                }
            }
        }

        case .RoomTransition: {
    //         if camera_position.move_t >= 1 {
    //             game_state.current_room_index = world_data.room_next_index;

    //             for entity in game_state.party {
    //                 (&game_state.entities.components_world_info[entity]).room_index = game_state.current_room_index;
    //             }

    //             room = &world_data.world.rooms[game_state.current_room_index];
    //             leader_destination := room_position_to_global_position({ 7, 4 }, room);
    //             entity_move_instant(leader, leader_destination, &game_state.entities);

    //             has_foe := false;
    //             for entity, component_world_info in game_state.entities.components_world_info {
    //                 if component_world_info.room_index == game_state.current_room_index {
    //                     component_flag, has_flag := game_state.entities.components_flag[entity];
    //                     if has_flag && .Foe in component_flag.value {
    //                         has_foe = true;
    //                     }
    //                 }
    //             }

    //             if has_foe {
    //                 set_world_mode(world_data, .Battle, World_Mode_Battle);
    //             } else {
    //                 set_world_mode(world_data, .Explore, World_Mode_Explore);
    //             }
    //         }
        }

        case .Battle: {
            // battle_mode_update(renderer_state, game_state, platform_state, world_data);
        }
    }
}

make_world :: proc(data: ^ldtk.LDTK, game_state: ^Game_State, world_data: ^Game_Mode_World) {
    context.allocator = game_state.game_mode_allocator;

    world_data.world_rooms = make([]Room, len(data.levels));

    for room_index := 0; room_index < len(data.levels); room_index += 1 {
        level := data.levels[room_index];
        layers := []int { LDTK_LAYER_TILES, LDTK_LAYER_GRID };

        for layer_index in layers {
            grid_layer_instance := level.layerInstances[layer_index];
            grid_layer_index := -1;
            for layer, i in data.defs.layers {
                if layer.uid == grid_layer_instance.layerDefUid {
                    grid_layer_index = i;
                    break;
                }
            }
            assert(grid_layer_index > -1, fmt.tprintf("Can't find layer with uid: %v", grid_layer_instance.layerDefUid));
            grid_layer := data.defs.layers[grid_layer_index];

            tileset_uid : i32 = -1;
            for tileset in data.defs.tilesets {
                if tileset.uid == grid_layer.tilesetDefUid {
                    tileset_uid = tileset.uid
                    break;
                }
            }
            assert(tileset_uid != -1, "Invalid tileset_uid");

            room_id : i32 = level.uid;
            room_size := Vector2i {
                level.pxWid / grid_layer.gridSize,
                level.pxHei / grid_layer.gridSize,
            };
            room_position := Vector2i {
                level.worldX / grid_layer.gridSize,
                level.worldY / grid_layer.gridSize,
            };

            for tile, i in grid_layer_instance.autoLayerTiles {
                cell_room_position := Vector2i {
                    tile.px.x / grid_layer.gridSize,
                    tile.px.y / grid_layer.gridSize,
                };
                grid_position := room_position + cell_room_position;
                source_position := Vector2i { tile.src[0], tile.src[1] };

                entity := entity_make(strings.clone(fmt.tprintf("Tile %v", grid_position)), &game_state.entities);
                game_state.entities.components_position[entity] = entity_make_component_position(grid_position);
                game_state.entities.components_world_info[entity] = Component_World_Info { i32(room_index) };
                game_state.entities.components_rendering[entity] = Component_Rendering {
                    true, game_state.textures[tileset_uid_to_texture_key(tileset_uid)],
                    source_position, { SPRITE_GRID_SIZE, SPRITE_GRID_SIZE },
                };
                game_state.entities.components_z_index[entity] = Component_Z_Index { 0 };
                game_state.entities.components_flag[entity] = Component_Flag { { .Tile } };

                append(&world_data.world_entities, entity);
            }

            for tile in grid_layer_instance.gridTiles {
                cell_room_position := Vector2i {
                    tile.px.x / grid_layer.gridSize,
                    tile.px.y / grid_layer.gridSize,
                };
                grid_position := room_position + cell_room_position;
                source_position := Vector2i { tile.src[0], tile.src[1] };

                entity := entity_make(strings.clone(fmt.tprintf("Tile %v", grid_position)), &game_state.entities);
                game_state.entities.components_position[entity] = entity_make_component_position(grid_position);
                game_state.entities.components_world_info[entity] = Component_World_Info { i32(room_index) };
                game_state.entities.components_rendering[entity] = Component_Rendering {
                    true, game_state.textures[tileset_uid_to_texture_key(tileset_uid)],
                    source_position, { SPRITE_GRID_SIZE, SPRITE_GRID_SIZE },
                };
                game_state.entities.components_z_index[entity] = Component_Z_Index { 1 };
                game_state.entities.components_flag[entity] = Component_Flag { { .Tile } };

                append(&world_data.world_entities, entity);
            }

            world_data.world_rooms[room_index] = Room { room_id, room_position, room_size, tileset_uid };
        }
    }
}

// make_world_entities :: proc(game_state: ^Game_State, world: ^World, allocator: runtime.Allocator) -> [dynamic]Entity {
//     context.allocator = allocator;
//     world_entities := make([dynamic]Entity);

//     for room, room_index in world.rooms {
//         // Grid
//         for cell_value, cell_index in room.grid {
//             cell_room_position := engine.grid_index_to_position(i32(cell_index), room.size.x);
//             grid_position := room.position + cell_room_position;
//             tile, tile_exists := room.tiles[cell_index];
//             source_position := Vector2i { tile.src[0], tile.src[1] };

//             entity := entity_make(strings.clone(fmt.tprintf("Tile %v", grid_position)), &game_state.entities);
//             game_state.entities.components_position[entity] = entity_make_component_position(grid_position);
//             game_state.entities.components_world_info[entity] = Component_World_Info { i32(room_index) };
//             game_state.entities.components_rendering[entity] = Component_Rendering {
//                 true, game_state.textures[tileset_uid_to_texture_key(room.tileset_uid)],
//                 source_position, { SPRITE_GRID_SIZE, SPRITE_GRID_SIZE },
//             };
//             game_state.entities.components_z_index[entity] = Component_Z_Index { 0 };
//             game_state.entities.components_flag[entity] = Component_Flag { { .Tile } };

//             append(&world_entities, entity);
//         }

//         // Entities
//         for entity_instance in room.entity_instances {
//             entity_def := world.entities[entity_instance.defUid];
//             entity := entity_make(strings.clone(entity_def.identifier), &game_state.entities);

//             source_position: Vector2i;
//             switch entity_def.identifier {
//                 case "Door": {
//                     source_position = { 32, 0 };
//                     direction: Vector2i;
//                     switch entity_instance.__grid {
//                         case { 14, 4 }:
//                             direction = { +1, 0 };
//                         case { 0, 4 }:
//                             direction = { -1, 0 };
//                         case { 7, 0 }:
//                             direction = { 0, -1 };
//                         case { 7, 8 }:
//                             direction = { 0, +1 };
//                     }
//                     game_state.entities.components_flag[entity] = Component_Flag { { .Interactive } };
//                     game_state.entities.components_door[entity] = Component_Door { direction };
//                 }
//                 case "Foe": {
//                     // TODO: use foe.id
//                     source_position = { 64, 0 };
//                     game_state.entities.components_flag[entity] = Component_Flag { { .Unit, .Foe } };
//                 }
//                 case "Event": {
//                     source_position = { 96, 0 };
//                     game_state.entities.components_flag[entity] = Component_Flag { { .Interactive } };
//                 }
//             }

//             grid_position : Vector2i = {
//                 room.position.x + entity_instance.__grid.x,
//                 room.position.y + entity_instance.__grid.y,
//             };
//             game_state.entities.components_position[entity] = entity_make_component_position(grid_position);
//             game_state.entities.components_world_info[entity] = Component_World_Info { i32(room_index) };
//             game_state.entities.components_rendering[entity] = Component_Rendering {
//                 true, game_state.textures["placeholder_0"],
//                 source_position, { 32, 32 },
//             };
//             game_state.entities.components_z_index[entity] = Component_Z_Index { 1 };

//             append(&world_entities, entity);
//         }
//     }

//     // log.debugf("world_entities: %v", world_entities);

//     return world_entities;
// }

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
        i32(f32(screen_position.x - rendering_offset.x) / f32(PIXEL_PER_CELL * rendering_scale)),
        i32(f32(screen_position.y - rendering_offset.y) / f32(PIXEL_PER_CELL * rendering_scale)),
    };
    return room_base + cell_position;
}

// screen_position_to_global_position :: proc(screen_position: Vector2i, room: ^Room, rendering_offset: Vector2i, rendering_scale: i32) -> Vector2i {
//     room_base := Vector2i {
//         room.position.x * room.size.x,
//         room.position.y * room.size.y,
//     };
//     cell_position := Vector2i {
//         i32(f32(screen_position.x - rendering_offset.x - LETTERBOX_SIZE.x * rendering_scale) / f32(PIXEL_PER_CELL * rendering_scale)),
//         i32(f32(screen_position.y - rendering_offset.y - LETTERBOX_SIZE.y * rendering_scale) / f32(PIXEL_PER_CELL * rendering_scale)),
//     };
//     return room_base + cell_position;
// }

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

tileset_uid_to_texture_key :: proc(tileset_uid: i32, allocator: runtime.Allocator = context.allocator) -> string {
    return strings.clone(fmt.tprintf("tileset_%v", tileset_uid), allocator);
}
