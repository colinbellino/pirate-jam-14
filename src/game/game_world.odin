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

                collision_component, has_collision := &game.entities.components_collision[player_entity];
                if has_collision == false {
                    break;
                }
                entity_size := Vector2f32 { collision_component.rect.w, collision_component.rect.h };
                entity_center := position_component.world_position + { collision_component.rect.x, collision_component.rect.y } + entity_size / 2;

                move_input := player_inputs.move;
                if move_input != 0 {
                    PLAYER_SPEED : f32 : 5.0; // TODO: store in component
                    move_delta := move_input * f32(delta_time) * f32(PLAYER_SPEED);

                    min_tile_x := position_component.grid_position.x - 1;
                    min_tile_y := position_component.grid_position.y - 1;
                    max_tile_x := position_component.grid_position.x + 1;
                    max_tile_y := position_component.grid_position.y + 1;
                    tile_size := Vector2f32 { 1, 1 };
                    diameter := tile_size + entity_size;
                    min_corner := diameter * -0.5;
                    max_corner := diameter * +0.5;

                    MAX_ITERATIONS := 4;
                    t_remaining : f32 = 1;
                    for i := 0; i < MAX_ITERATIONS && t_remaining > 0; i += 1 {
                        t_min : f32 = 1;
                        wall_normal := Vector2f32 { 0, 0 };

                        for tile_y := min_tile_y; tile_y <= max_tile_y; tile_y += 1 {
                            for tile_x := min_tile_x; tile_x <= max_tile_x; tile_x += 1 {
                                tile_grid_position := Vector2i { tile_x , tile_y };
                                tile_world_position := Vector2f32 { f32(tile_x) , f32(tile_y) };
                                tile_center := tile_world_position + tile_size / 2;
                                is_empty := is_tile_empty(game, tile_grid_position);

                                // append_debug_line(game,
                                //     Vector2i(array_cast(entity_center * PIXEL_PER_CELL, i32)),
                                //     Vector2i(array_cast(tile_center * PIXEL_PER_CELL, i32)),
                                //     { 255, 255, 255, 255 },
                                // );

                                debug_rect_color := engine.Color { 0, 0, 255, 100 };

                                if is_empty == false {
                                    debug_rect_color = engine.Color { 255, 0, 0, 100 };

                                    rel := entity_center - tile_center;
                                    if test_wall(min_corner.x, rel.x, rel.y, move_delta.x, move_delta.y, min_corner.y, max_corner.y, &t_min) {
                                        wall_normal = { 1, 0 };
                                    }
                                    if test_wall(max_corner.x, rel.x, rel.y, move_delta.x, move_delta.y, min_corner.y, max_corner.y, &t_min) {
                                        wall_normal = { -1, 0 };
                                    }
                                    if test_wall(min_corner.y, rel.y, rel.x, move_delta.y, move_delta.x, min_corner.x, max_corner.x, &t_min) {
                                        wall_normal = { 0, 1 };
                                    }
                                    if test_wall(max_corner.y, rel.y, rel.x, move_delta.y, move_delta.x, min_corner.x, max_corner.x, &t_min) {
                                        wall_normal = { 0, -1 };
                                    }
                                }

                                debug_rect_position := world_to_camera_position(camera_position^, Vector2i {
                                    i32(f32(tile_grid_position.x) + 1 - tile_size.x),
                                    i32(f32(tile_grid_position.y) + 1 - tile_size.y),
                                });
                                debug_rect := RectF32 {
                                    f32(debug_rect_position.x * PIXEL_PER_CELL),
                                    f32(debug_rect_position.y * PIXEL_PER_CELL),
                                    diameter.x * PIXEL_PER_CELL,
                                    diameter.y * PIXEL_PER_CELL,
                                };
                                append_debug_rect(game, debug_rect, debug_rect_color);

                                // append_debug_line(game,
                                //     Vector2i(array_cast((tile_world_position + min_corner) * PIXEL_PER_CELL, i32)),
                                //     Vector2i(array_cast((tile_world_position + max_corner) * PIXEL_PER_CELL, i32)),
                                //     { 255, 255, 255, 255 },
                                // );
                            }
                        }

                        move_delta *= t_min;
                        move_delta -= 1 * (move_delta * wall_normal) * wall_normal;
                        entity_move_world(position_component, position_component.world_position + move_delta);

                        t_remaining -= t_min * t_remaining;
                    }

                    entity_center_camera_position := world_to_camera_position(camera_position^, entity_center);

                    append_debug_line(game,
                        Vector2i(array_cast(entity_center_camera_position * PIXEL_PER_CELL, i32)),
                        Vector2i(array_cast((entity_center_camera_position + move_input) * PIXEL_PER_CELL, i32)),
                        { 255, 255, 255, 255 },
                    );
                    append_debug_line(game,
                        Vector2i(array_cast(entity_center_camera_position * PIXEL_PER_CELL, i32)),
                        Vector2i(array_cast((entity_center_camera_position + move_input * t_min) * PIXEL_PER_CELL, i32)),
                        { 255, 0, 0, 255 },
                    );

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
                }

                {
                    debug_rect := RectF32 {
                        entity_center.x + 0.5 * PIXEL_PER_CELL,
                        entity_center.y + 0.5 * PIXEL_PER_CELL,
                        1,
                        1,
                    };
                    append_debug_rect(game, debug_rect, { 255, 0, 0, 255 });
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

test_wall :: proc(wall_x, rel_x, rel_y, player_delta_x, player_delta_y, min_y, max_y: f32, t_min: ^f32) -> bool {
    if player_delta_x == 0 {
        return false;
    }

    // Formula: ts := (wx - p0x) / dx;
    // Source: https://youtu.be/5KzJ0TDeLxQ?t=3757
    t_result := (wall_x - rel_x) / player_delta_x;
    y := rel_y + t_result * player_delta_y;
    t_epsilon : f32 = 0.0001;

    if t_result >= 0 && t_min^ > t_result {
        if y >= min_y && y <= max_y {
            t_min^ = max(0, t_result - t_epsilon);
            return true;
        }
    }

    return false;
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
                game.entities.components_tile[entity] = Component_Tile { tile.t };
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
            if has_position && position_component.grid_position == position {
                tile_component, has_tile := game.entities.components_tile[entity];
                if has_tile {
                    return debug_tile_is_empty(i32(tile_component.tile_id));
                }
            }
        }
    }
    return false;
}

debug_tile_is_empty :: proc(tile_id: i32) -> bool {
    ids := [?]i32 { 256, 257, 258, 259, 320, 321, 322, 323, 324, 356, 359, 386, 387, 391, 2272 };
    for id in ids {
        if id == tile_id {
            return false;
        }
    }
    return true;
}
