package game

import "core:fmt"
import "core:log"
import "core:os"
import "core:mem"
import "core:runtime"
import "core:time"
import "core:strings"

import "../engine"

LDTK_LAYER_ENTITIES     :: 0;
LDTK_LAYER_TILES        :: 1;
LDTK_LAYER_GRID         :: 2;

Init_State :: enum { Default, Busy, Done };

Game_Mode_World :: struct {
    initialized:            Init_State,
    world_mode:             World_Mode,
    world_mode_arena:       mem.Arena,
    world_mode_allocator:   mem.Allocator,
    world_mode_data:        ^World_Mode_Data,

    world_entities:         [dynamic]Entity,
    world_rooms:            []Room,
    world_tileset_assets:   map[engine.LDTK_Tileset_Uid]engine.Asset_Id,
    world_file_last_change: time.Time,
    room_next_index:        i32,
    mouse_cursor:           Entity,
}

World_Mode :: enum {
    Explore,
    RoomTransition,
}

World_Mode_Data :: union {
    World_Mode_Explore,
    World_Mode_RoomTransition,
}
World_Mode_Explore :: struct { }
World_Mode_RoomTransition :: struct { }

Room :: struct {
    id:                 i32,
    position:           Vector2i,
    size:               Vector2i,
    tileset_uid:        engine.LDTK_Tileset_Uid,
}

world_mode_update :: proc(
    app: ^engine.App,
    delta_time: f64,
) {
    game := cast(^Game_State) app.game;
    player_inputs := &game.player_inputs[0];

    world_data := cast(^Game_Mode_World) game.game_mode_data;

    if world_data.initialized == .Default {
        world_data.world_mode_allocator = engine.make_arena_allocator(.WorldMode, WORLD_MODE_ARENA_SIZE, &world_data.world_mode_arena, game.game_mode_allocator, app);
        context.allocator = world_data.world_mode_allocator;

        // game.draw_letterbox = true;
        game.draw_hud = true;

        engine.asset_load(app, game.asset_world);
        engine.asset_load(app, game.asset_placeholder);
        engine.asset_load(app, game.asset_units);

        world_data.initialized = .Busy;
        return;
    }

    if world_data.initialized == .Busy {
        world_asset := &app.assets.assets[game.asset_world];
        if world_asset.state == .Loaded {
            asset_info := world_asset.info.(engine.Asset_Info_Map);
            log.infof("Level %v loaded: %s (%s)", world_asset.file_name, asset_info.ldtk.iid, asset_info.ldtk.jsonVersion);

            // FIXME: wait for world to be loaded
            // FIXME: then, wait for all tilesets
            // FIXME: then, make the world and set world_data.initialized = .Done
            for tileset in asset_info.ldtk.defs.tilesets {
                rel_path, value_ok := tileset.relPath.?;
                if value_ok != true {
                    continue;
                }

                path, path_ok := strings.replace(rel_path, static_string("../art"), static_string("media/art"), 1);
                if path_ok != true {
                    log.warnf("Invalid tileset: %s", rel_path);
                    continue;
                }

                asset, asset_found := engine.asset_get_by_file_name(app.assets, path);
                if asset_found == false {
                    log.warnf("Tileset asset not found: %s", path);
                    continue;
                }

                world_data.world_tileset_assets[tileset.uid] = asset.id;
                engine.asset_load(app, asset.id);
            }
            make_world(asset_info.ldtk, game, world_data, game.game_mode_allocator);

            {
                entity := entity_make("Mouse cursor", &game.entities);
                game.entities.components_position[entity] = entity_make_component_position({ 0, 0 });
                // game.entities.components_world_info[entity] = Component_World_Info { game.current_room_index };
                game.entities.components_rendering[entity] = Component_Rendering {
                    true, game.asset_placeholder,
                    { 32, 0 }, { 32, 32 },
                };
                game.entities.components_z_index[entity] = Component_Z_Index { 99 };
                world_data.mouse_cursor = entity;
            }

            {
                room := &world_data.world_rooms[game.current_room_index];
                entity := entity_make("Camera", &game.entities);
                world_position := Vector2f32 {
                    f32(room.position.x * room.size.x) / f32(PIXEL_PER_CELL),
                    f32(room.position.y * room.size.y) / f32(PIXEL_PER_CELL),
                };
                game.entities.components_position[entity] = Component_Position {};
                (&game.entities.components_position[entity]).world_position = world_position;
                game.camera = entity;
            }

            world_data.initialized = .Done;
        }

        return;
    }

    room := &world_data.world_rooms[game.current_room_index];
    camera_position := &game.entities.components_position[game.camera];

    { // Update mouse position
        game.mouse_grid_position = screen_position_to_global_position(game.mouse_screen_position, room, app.renderer.rendering_offset, app.renderer.rendering_scale);
        entity_move_grid(world_data.mouse_cursor, game.mouse_grid_position, &game.entities);
    }

    player_entities := []Entity {
        game.party[0],
        // game.party[1],
    }

    switch world_data.world_mode {
        case .Explore: {
            explore_data := cast(^World_Mode_Explore) world_data.world_mode_data;

            for player_entity, player_index in player_entities {
                position_component, has_position := &game.entities.components_position[player_entity];
                if has_position != true {
                    break;
                }

                entity_center := position_component.world_position + Vector2f32 { 0.5, 0.5 };

                move_input := player_inputs.move;
                if move_input != 0 {
                    PLAYER_SPEED : f32 : 5.0;
                    new_relative_position := move_input * f32(delta_time) * PLAYER_SPEED;

                    old_grid_position := position_component.grid_position;
                    // new_grid_position := position_component.grid_position + new_relative_position
                    // TODO:
                    // min_tile_x := min(old_grid_position.x, new_grid_position.x);
                    // min_tile_y := min(old_grid_position.y, new_grid_position.y);
                    // max_tile_x := max(old_grid_position.x, new_grid_position.x) + 1;
                    // max_tile_y := max(old_grid_position.y, new_grid_position.y) + 1;
                    min_tile_x := old_grid_position.x - 1;
                    min_tile_y := old_grid_position.y - 1;
                    max_tile_x := old_grid_position.x + 1;
                    max_tile_y := old_grid_position.y + 1;

                    // FIXME: Not gonna be able to finish this tonight, so here: https://www.youtube.com/watch?v=rWpZLvbT02o&t=389s&ab_channel=MollyRocket
                    for tile_y := min_tile_x; tile_y <= max_tile_y; tile_y += 1 {
                        for tile_x := min_tile_x; tile_x <= max_tile_x; tile_x += 1 {
                            is_empty := is_tile_empty(game, { tile_x, tile_y });
                            if is_empty == false {
                                wall_x : f32 = 0;
                                // log.debugf("is_empty: %v,%v %v", tile_x, tile_y, is_empty);

                                // ts := (wx - p0x) / dx;
                                // TODO: Not sure about p0x
                                result := (wall_x - move_input.x) / new_relative_position.x;
                                // check_wall(min_corner.x, min_corner.y, max_corner.y, new_relative_position.x);
                            }
                        }
                    }

                    entity_move_world(position_component, position_component.world_position + new_relative_position);
                    // log.debugf("position_component: %v", position_component);

                    room_transition: Vector2i;
                    if entity_center.x < camera_position.world_position.x {
                        room_transition = { -1, 0 };
                    } else if entity_center.x > camera_position.world_position.x + f32(room.size.x) {
                        room_transition = { +1, 0 };
                    } else if entity_center.y < camera_position.world_position.y {
                        room_transition = { 0, -1 };
                    } else if entity_center.y > camera_position.world_position.y + f32(room.size.y) {
                        room_transition = { 0, +1 };
                    }

                    if room_transition != 0 {
                        camera_destination := camera_position.world_position + Vector2f32(array_cast(room_transition * room.size, f32));
                        entity_move_lerp_world(camera_position, camera_destination, 3.0);
                        player_destination := position_component.world_position + Vector2f32(array_cast(room_transition, f32)) * 0.5;
                        entity_move_lerp_world(position_component, player_destination, 3.0);
                        set_world_mode(world_data, .RoomTransition, World_Mode_RoomTransition);
                    }

                    game.debug_lines[player_index * 10] = engine.Line {
                        Vector2i(array_cast(entity_center * PIXEL_PER_CELL, i32)),
                        Vector2i(array_cast((entity_center + move_input) * PIXEL_PER_CELL, i32)),
                        { 255, 255, 255, 255 },
                    }
                    // game.debug_lines[player_index * 10 + 1] = engine.Line {
                    //     Vector2i(array_cast(entity_center * PIXEL_PER_CELL, i32)),
                    //     Vector2i(array_cast((new_world_position + { 0.5, 0.5 }) * PIXEL_PER_CELL, i32)),
                    //     { 255, 0, 0, 255 },
                    // }
                }
            }
        }

        case .RoomTransition: {
            // TODO: use something like that: is_done_moving()
            if camera_position.move_t >= 1 {
                set_world_mode(world_data, .Explore, World_Mode_Explore);
            }
        }
    }

}

make_world :: proc(data: ^engine.LDTK_Root, game: ^Game_State, world_data: ^Game_Mode_World, allocator : runtime.Allocator) {
    context.allocator = allocator;

    world_data.world_rooms = make([]Room, len(data.levels));

    for room_index := 0; room_index < len(data.levels); room_index += 1 {
        level := data.levels[room_index];

        layers := []int { LDTK_LAYER_TILES, LDTK_LAYER_GRID };
        for layer_index in layers {
            layer_instance := level.layerInstances[layer_index];

            grid_layer_index := -1;
            for layer, i in data.defs.layers {
                if layer.uid == layer_instance.layerDefUid {
                    grid_layer_index = i;
                    break;
                }

            }
            assert(grid_layer_index > -1, fmt.tprintf("Can't find layer with uid: %v", layer_instance.layerDefUid));
            grid_layer := data.defs.layers[grid_layer_index];

            tileset_uid : engine.LDTK_Tileset_Uid = -1;
            for tileset in data.defs.tilesets {
                if tileset.uid == grid_layer.tilesetDefUid {
                    tileset_uid = tileset.uid
                    break;
                }
            }
            assert(tileset_uid != -1, "Invalid tileset_uid");

            room_id : i32 = i32(level.uid);
            room_size := Vector2i {
                level.pxWid / grid_layer.gridSize,
                level.pxHei / grid_layer.gridSize,
            };
            room_position := Vector2i {
                level.worldX / grid_layer.gridSize,
                level.worldY / grid_layer.gridSize,
            };

            for tile, i in layer_instance.autoLayerTiles {
                cell_room_position := Vector2i {
                    tile.px.x / grid_layer.gridSize,
                    tile.px.y / grid_layer.gridSize,
                };
                grid_position := room_position + cell_room_position;
                source_position := Vector2i { tile.src[0], tile.src[1] };

                entity := entity_make(fmt.tprintf("Tile %v", grid_position), &game.entities);
                game.entities.components_position[entity] = entity_make_component_position(grid_position);
                game.entities.components_world_info[entity] = Component_World_Info { i32(room_index) };
                game.entities.components_rendering[entity] = Component_Rendering {
                    true, world_data.world_tileset_assets[tileset_uid],
                    source_position, { SPRITE_GRID_SIZE, SPRITE_GRID_SIZE },
                };
                game.entities.components_z_index[entity] = Component_Z_Index { 0 };
                game.entities.components_flag[entity] = Component_Flag { { .Tile } };

                append(&world_data.world_entities, entity);
            }

            for tile in layer_instance.gridTiles {
                cell_room_position := Vector2i {
                    tile.px.x / grid_layer.gridSize,
                    tile.px.y / grid_layer.gridSize,
                };
                grid_position := room_position + cell_room_position;
                source_position := Vector2i { tile.src[0], tile.src[1] };

                entity := entity_make(fmt.tprintf("Tile %v", grid_position), &game.entities);
                game.entities.components_position[entity] = entity_make_component_position(grid_position);
                game.entities.components_world_info[entity] = Component_World_Info { i32(room_index) };
                game.entities.components_rendering[entity] = Component_Rendering {
                    true, world_data.world_tileset_assets[tileset_uid],
                    source_position, { SPRITE_GRID_SIZE, SPRITE_GRID_SIZE },
                };
                game.entities.components_z_index[entity] = Component_Z_Index { 1 };
                game.entities.components_flag[entity] = Component_Flag { { .Tile } };

                append(&world_data.world_entities, entity);
            }

            world_data.world_rooms[room_index] = Room { room_id, room_position, room_size, tileset_uid };
        }

        {
            layer_instance := level.layerInstances[LDTK_LAYER_ENTITIES];

            entity_layer_index := -1;
            for layer, i in data.defs.layers {
                if layer.uid == layer_instance.layerDefUid {
                    entity_layer_index = i;
                    break;
                }
            }
            assert(entity_layer_index > -1, fmt.tprintf("Can't find layer with uid: %v", layer_instance.layerDefUid));
            layer := data.defs.layers[entity_layer_index];

            room_position := Vector2i {
                level.worldX / layer.gridSize,
                level.worldY / layer.gridSize,
            };

            entities := map[engine.LDTK_Entity_Uid]engine.LDTK_Entity {};
            for entity in data.defs.entities {
                entities[entity.uid] = entity;
                // log.debug("entity: %s", entity);
            }

            for entity_instance in layer_instance.entityInstances {
                entity_def := entities[entity_instance.defUid];
                // log.debug("entity: %s", entity_def);

                cell_room_position := Vector2i {
                    entity_instance.px.x / layer.gridSize,
                    entity_instance.px.y / layer.gridSize,
                };
                grid_position := room_position + cell_room_position;
                source_position := Vector2i { entity_instance.width, entity_instance.height };

                entity := entity_make(fmt.tprintf("Entity %v", entity_def.identifier), &game.entities);
                game.entities.components_position[entity] = entity_make_component_position(grid_position);
                game.entities.components_world_info[entity] = Component_World_Info { i32(room_index) };
                game.entities.components_rendering[entity] = Component_Rendering {
                    true, game.asset_placeholder,
                    { 32, 32 }, { 32, 32 },
                };
                game.entities.components_z_index[entity] = Component_Z_Index { 2 };
                game.entities.components_flag[entity] = Component_Flag { { .Foe } };

                append(&world_data.world_entities, entity);
            }
        }
    }
}

// make_world_entities :: proc(game: ^Game_State, world: ^World, allocator: runtime.Allocator) -> [dynamic]Entity {
//     context.allocator = allocator;
//     world_entities := make([dynamic]Entity);

//     for room, room_index in world.rooms {
//         // Grid
//         for cell_value, cell_index in room.grid {
//             cell_room_position := engine.grid_index_to_position(i32(cell_index), room.size.x);
//             grid_position := room.position + cell_room_position;
//             tile, tile_exists := room.tiles[cell_index];
//             source_position := Vector2i { tile.src[0], tile.src[1] };

//             entity := entity_make(fmt.tprintf("Tile %v", grid_position), &game.entities);
//             game.entities.components_position[entity] = entity_make_component_position(grid_position);
//             game.entities.components_world_info[entity] = Component_World_Info { i32(room_index) };
//             game.entities.components_rendering[entity] = Component_Rendering {
//                 true, game.textures[tileset_uid_to_texture_key(room.tileset_uid)],
//                 source_position, { SPRITE_GRID_SIZE, SPRITE_GRID_SIZE },
//             };
//             game.entities.components_z_index[entity] = Component_Z_Index { 0 };
//             game.entities.components_flag[entity] = Component_Flag { { .Tile } };

//             append(&world_entities, entity);
//         }

//         // Entities
//         for entity_instance in room.entity_instances {
//             entity_def := world.entities[entity_instance.defUid];
//             entity := entity_make(entity_def.identifier, &game.entities);

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
//                     game.entities.components_flag[entity] = Component_Flag { { .Interactive } };
//                     game.entities.components_door[entity] = Component_Door { direction };
//                 }
//                 case "Foe": {
//                     // TODO: use foe.id
//                     source_position = { 64, 0 };
//                     game.entities.components_flag[entity] = Component_Flag { { .Unit, .Foe } };
//                 }
//                 case "Event": {
//                     source_position = { 96, 0 };
//                     game.entities.components_flag[entity] = Component_Flag { { .Interactive } };
//                 }
//             }

//             grid_position : Vector2i = {
//                 room.position.x + entity_instance.__grid.x,
//                 room.position.y + entity_instance.__grid.y,
//             };
//             game.entities.components_position[entity] = entity_make_component_position(grid_position);
//             game.entities.components_world_info[entity] = Component_World_Info { i32(room_index) };
//             game.entities.components_rendering[entity] = Component_Rendering {
//                 true, game.textures["placeholder_0"],
//                 source_position, { 32, 32 },
//             };
//             game.entities.components_z_index[entity] = Component_Z_Index { 1 };

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

tileset_uid_to_texture_key :: proc(tileset_uid: i32, allocator: runtime.Allocator = context.allocator) -> string {
    return static_string(fmt.tprintf("tileset_%v", tileset_uid), allocator);
}

// FIXME: replace this shit, we need to be able to get the tiles by x,y pos
is_tile_empty :: proc(game: ^Game_State, position: Vector2i) -> bool {
    for entity in game.entities.entities {
        component_flag, has_flag := game.entities.components_flag[entity];
        if has_flag && .Tile in component_flag.value {
            position_component, has_position := &game.entities.components_position[entity];
            rendering_component, has_rendering := game.entities.components_rendering[entity];
            if has_position && has_rendering && position_component.grid_position == position {
                // log.debugf("rendering_component: %v", rendering_component);
                return debug_tile_is_empty(rendering_component);
            }
        }
    }
    return true;
}

debug_tile_is_empty :: proc(rendering_component: Component_Rendering) -> bool {
    return rendering_component.texture_position != { 48, 80 } && rendering_component.texture_position != { 0, 64 };
}
