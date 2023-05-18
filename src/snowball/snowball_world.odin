package snowball

import "core:log"
import "core:strings"
import "core:fmt"
import "core:runtime"
import "core:mem"

import "../engine"

LDTK_LAYER_ENTITIES     :: 0;
LDTK_LAYER_TILES        :: 1;
LDTK_LAYER_GRID         :: 2;

Game_Mode_World :: struct {
    world_entities:         [dynamic]Entity,
    world_rooms:            []Room,
    world_tileset_assets:   map[engine.LDTK_Tileset_Uid]engine.Asset_Id,
}

Room :: struct {
    id:                 i32,
    position:           Vector2i,
    size:               Vector2i,
    tileset_uid:        engine.LDTK_Tileset_Uid,
}

game_world :: proc() {
    if game_mode_enter() {
        context.allocator = game.game_mode_allocator;
        game.world_data = new(Game_Mode_World);

        engine.asset_load(app, game.asset_world);
        world_asset := &app.assets.assets[game.asset_world];
        asset_info := world_asset.info.(engine.Asset_Info_Map);
        log.infof("Level %v loaded: %s (%s)", world_asset.file_name, asset_info.ldtk.iid, asset_info.ldtk.jsonVersion);

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

            game.world_data.world_tileset_assets[tileset.uid] = asset.id;
            engine.asset_load(app, asset.id);
        }
        make_world(asset_info.ldtk, game, game.world_data, game.game_mode_allocator);
    }

    context.allocator = game.game_mode_allocator;

    if engine.ui_window(app.ui, "Worldmap", { 400, 400, 200, 100 }, { .NO_CLOSE, .NO_RESIZE }) {
        engine.ui_layout_row(app.ui, { -1 }, 0);
        if .SUBMIT in engine.ui_button(app.ui, "Battle 1") {
            game.battle_index = 1;
            game_mode_transition(.Battle);
        }
        if .SUBMIT in engine.ui_button(app.ui, "Battle 2") {
            game.battle_index = 2;
            game_mode_transition(.Battle);
        }
        if .SUBMIT in engine.ui_button(app.ui, "Battle 3") {
            game.battle_index = 3;
            game_mode_transition(.Battle);
        }
    }

    // if game_mode_exit() {
    //     log.debug("exit inner");
    //     // for entity in game.world_data.world_entities {
    //     //     entity_delete(entity, &game.entities);
    //     // }
    //     // clear(&game.world_data.world_entities);
    //     // delete(game.world_data.world_rooms);
    //     // delete(game.world_data.world_tileset_assets);
    // }
}

create_tile :: proc(position: Vector2i, sprite_position: Vector2i) -> Entity {
    entity := entity_make("Tile", &game.entities);
    game.entities.components_position[entity] = entity_make_component_position(position);
    game.entities.components_rendering[entity] = Component_Rendering {
        true, game.asset_tilemap,
        sprite_position * PIXEL_PER_CELL, { PIXEL_PER_CELL, PIXEL_PER_CELL },
    };
    game.entities.components_z_index[entity] = Component_Z_Index { 2 };
    game.entities.components_flag[entity] = Component_Flag { { .Tile } };
    return entity;
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
                    source_position, { PIXEL_PER_CELL, PIXEL_PER_CELL },
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
                    source_position, { PIXEL_PER_CELL, PIXEL_PER_CELL },
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
