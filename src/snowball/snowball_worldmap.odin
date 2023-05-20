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

Game_Mode_Worldmap :: struct {
    entities:             [dynamic]Entity,
    level:                Level,
}

Level :: struct {
    id:                 i32,
    position:           Vector2i,
    size:               Vector2i,
    tileset_uid:        engine.LDTK_Tileset_Uid,
}

game_mode_update_worldmap :: proc() {
    if game_mode_enter() {
        context.allocator = game.game_mode_allocator;
        game.world_data = new(Game_Mode_Worldmap);

        world_asset := &app.assets.assets[game.asset_worldmap];
        asset_info, asset_ok := world_asset.info.(engine.Asset_Info_Map);
        assert(asset_ok);
        game.world_data.level, game.world_data.entities = make_level(asset_info.ldtk, 0, game.tileset_assets, game.game_allocator);
        // log.debugf("game.world_data.level: %v", game.world_data.level);
    }

    if engine.ui_window(app.ui, "Worldmap", { 400, 400, 200, 100 }, { .NO_CLOSE, .NO_RESIZE }) {
        engine.ui_layout_row(app.ui, { -1 }, 0);
        if .SUBMIT in engine.ui_button(app.ui, "Battle 1") {
            game.battle_index = 0;
            game_mode_transition(.Battle);
        }
        if .SUBMIT in engine.ui_button(app.ui, "Battle 2") {
            game.battle_index = 1;
            game_mode_transition(.Battle);
        }
        if .SUBMIT in engine.ui_button(app.ui, "Battle 3") {
            game.battle_index = 2;
            game_mode_transition(.Battle);
        }
    }

    if game_mode_exit(.WorldMap) {
        log.debug("Worldmap exit");
        for entity in game.world_data.entities {
            entity_delete(entity, &game.entities);
        }
    }
}

create_tile :: proc(position: Vector2i, sprite_position: Vector2i) -> Entity {
    entity := entity_make("Tile", &game.entities);
    game.entities.components_position[entity] = entity_make_component_position(position);
    game.entities.components_rendering[entity] = Component_Rendering {
        true, game.asset_tilemap,
        sprite_position * GRID_SIZE, GRID_SIZE_V2, .NONE,
    };
    game.entities.components_z_index[entity] = Component_Z_Index { 2 };
    game.entities.components_flag[entity] = Component_Flag { { .Tile } };
    return entity;
}

make_level :: proc(data: ^engine.LDTK_Root, room_index: int, tileset_assets: map[engine.LDTK_Tileset_Uid]engine.Asset_Id, allocator := context.allocator) -> (Level, [dynamic]Entity) {
    context.allocator = allocator;

    entities := make([dynamic]Entity, game.game_mode_allocator);
    room := new(Level, game.game_mode_allocator);

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
            grid_position := /* room_position + */ cell_room_position;
            source_position := Vector2i { tile.src[0], tile.src[1] };

            entity := entity_make(fmt.tprintf("Tile %v", grid_position), &game.entities);
            game.entities.components_position[entity] = entity_make_component_position(grid_position);
            (&game.entities.components_position[entity]).size = { GRID_SIZE, GRID_SIZE };
            game.entities.components_world_info[entity] = Component_World_Info { i32(room_index) };
            game.entities.components_rendering[entity] = Component_Rendering { };
            (&game.entities.components_rendering[entity]).visible = true;
            (&game.entities.components_rendering[entity]).texture_asset = tileset_assets[tileset_uid];
            (&game.entities.components_rendering[entity]).texture_position = source_position;
            (&game.entities.components_rendering[entity]).texture_size = GRID_SIZE_V2;
            (&game.entities.components_rendering[entity]).flip = transmute(engine.RendererFlip) tile.f;
            game.entities.components_z_index[entity] = Component_Z_Index { 0 };
            game.entities.components_flag[entity] = Component_Flag { { .Tile } };

            append(&entities, entity);
        }

        for tile in layer_instance.gridTiles {
            cell_room_position := Vector2i {
                tile.px.x / grid_layer.gridSize,
                tile.px.y / grid_layer.gridSize,
            };
            grid_position := /* room_position + */ cell_room_position;
            source_position := Vector2i { tile.src[0], tile.src[1] };

            entity := entity_make(fmt.tprintf("Tile %v", grid_position), &game.entities);
            game.entities.components_position[entity] = entity_make_component_position(grid_position);
            game.entities.components_world_info[entity] = Component_World_Info { i32(room_index) };
            game.entities.components_tile[entity] = Component_Tile { tile.t };
            game.entities.components_rendering[entity] = Component_Rendering { };
            (&game.entities.components_rendering[entity]).visible = true;
            (&game.entities.components_rendering[entity]).texture_asset = tileset_assets[tileset_uid];
            (&game.entities.components_rendering[entity]).texture_position = source_position;
            (&game.entities.components_rendering[entity]).texture_size = GRID_SIZE_V2;
            (&game.entities.components_rendering[entity]).flip = transmute(engine.RendererFlip) tile.f;
            game.entities.components_z_index[entity] = Component_Z_Index { 1 };
            game.entities.components_flag[entity] = Component_Flag { { .Tile } };

            append(&entities, entity);
        }

        room^ = Level { room_id, room_position, room_size, tileset_uid };
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

        ldtk_entities := map[engine.LDTK_Entity_Uid]engine.LDTK_Entity {};
        for entity in data.defs.entities {
            ldtk_entities[entity.uid] = entity;
            // log.debug("entity: %s", entity);
        }

        for entity_instance in layer_instance.entityInstances {
            entity_def := ldtk_entities[entity_instance.defUid];
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
                { 32, 32 }, { 32, 32 }, .NONE,
            };
            game.entities.components_z_index[entity] = Component_Z_Index { 2 };
            game.entities.components_flag[entity] = Component_Flag { { .Foe } };

            append(&entities, entity);
        }
    }

    return room^, entities;
}
