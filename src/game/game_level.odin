package game

import "core:fmt"
import "core:log"
import "core:slice"
import "core:strings"

import "../engine"

LDTK_LAYER_ENTITIES     :: 0
LDTK_LAYER_TILES        :: 1
LDTK_LAYER_GRID         :: 2

Level :: struct {
    id:                 i32,
    position:           Vector2i32,
    size:               Vector2i32,
    tileset_uid:        engine.LDTK_Tileset_Uid,
    grid:               []Grid_Cell,
}
Grid_Cell :: bit_set[Grid_Cell_Flags]
Grid_Cell_Flags :: enum {
    None     = 0,
    Climb    = 1,
    Fall     = 2,
    Move     = 4,
    Grounded = 8,
}

update_grid_flags :: proc(level: ^Level) {
    for grid_index := 0; grid_index < len(level.grid); grid_index += 1 {
        cell_below, has_cell_below := get_cell_by_index_with_offset(level, grid_index, { 0, 1 })
        if has_cell_below && .Move in cell_below {
            level.grid[grid_index] |= { .Grounded }
        }
    }
}

get_cell_by_index_with_offset :: proc(level: ^Level, grid_index: int, offset: Vector2i32) -> (^Grid_Cell, bool) {
    position := engine.grid_index_to_position(grid_index, level.size.x)
    below_index := engine.grid_position_to_index(position + offset, level.size.x)
    if below_index < 0 || below_index >= len(level.grid) {
        return nil, false
    }
    return &_game.battle_data.level.grid[below_index], true
}

int_grid_csv_to_flags :: proc(grid_value: i32) -> (result: Grid_Cell) {
    switch grid_value {
        case 0: result = { .Fall, .Move }
        case 3: result = { .Fall, .Move }
        case 4: result = { .Climb }
        case 5: result = { .Climb, .Move }
    }
    return
}

load_level_assets :: proc(level_asset_info: engine.Asset_Info_Map, assets_state: ^engine.Assets_State) -> (level_assets: map[engine.LDTK_Tileset_Uid]engine.Asset_Id) {
    for tileset in level_asset_info.ldtk.defs.tilesets {
        rel_path, value_ok := tileset.relPath.?
        if value_ok != true {
            continue
        }

        path, path_ok := strings.replace(rel_path, static_string("../art"), static_string("media/art"), 1)
        if path_ok != true {
            log.warnf("Invalid tileset: %s", rel_path)
            continue
        }

        asset, asset_found := engine.asset_get_by_file_name(assets_state, path)
        if asset_found == false {
            log.errorf("Tileset asset not found: %s", path)
            continue
        }

        level_assets[tileset.uid] = asset.id
        engine.asset_load(asset.id, engine.Image_Load_Options { engine.RENDERER_NEAREST, engine.RENDERER_CLAMP_TO_EDGE })
    }

    return
}

make_level :: proc(data: ^engine.LDTK_Root, target_level_index: int, tileset_assets: map[engine.LDTK_Tileset_Uid]engine.Asset_Id, level_entities: ^[dynamic]Entity, allocator := context.allocator) -> Level {
    context.allocator = allocator

    target_level := new(Level, _game.game_mode.allocator)

    assert(target_level_index < len(data.levels), fmt.tprintf("Level out of bounds: %v / %v", target_level_index, len(data.levels)))
    level := data.levels[target_level_index]

    layers := []int { LDTK_LAYER_TILES, LDTK_LAYER_GRID }
    for layer_index in layers {
        layer_instance := level.layerInstances[layer_index]

        grid_layer_index := -1
        for layer, i in data.defs.layers {
            if layer.uid == layer_instance.layerDefUid {
                grid_layer_index = i
                break
            }

        }
        assert(grid_layer_index > -1, fmt.tprintf("Can't find layer with uid: %v", layer_instance.layerDefUid))
        grid_layer := data.defs.layers[grid_layer_index]

        tileset_uid : engine.LDTK_Tileset_Uid = -1
        for tileset in data.defs.tilesets {
            if tileset.uid == grid_layer.tilesetDefUid {
                tileset_uid = tileset.uid
                break
            }
        }
        assert(tileset_uid != -1, "Invalid tileset_uid")

        target_level_id : i32 = i32(level.uid)
        target_level_size := Vector2i32 {
            level.pxWid / grid_layer.gridSize,
            level.pxHei / grid_layer.gridSize,
        }
        target_level_position := Vector2i32 {
            level.worldX / grid_layer.gridSize,
            level.worldY / grid_layer.gridSize,
        }

        for tile, i in layer_instance.autoLayerTiles {
            local_position := Vector2i32 {
                tile.px.x / grid_layer.gridSize,
                tile.px.y / grid_layer.gridSize,
            }
            source_position := Vector2i32 { tile.src[0], tile.src[1] }

            if tileset_uid in tileset_assets == false {
                log.debugf("tileset_assets: %v", tileset_assets)
            }
            assert(tileset_uid in tileset_assets)

            entity := entity_make(fmt.tprintf("AutoTile %v", local_position))
            entity_add_transform_grid(entity, local_position, grid_layer.gridSize)
            entity_add_sprite(entity, tileset_assets[tileset_uid], source_position, texture_padding = 1, z_index = 1)
            _game.entities.components_flag[entity] = Component_Flag { { .Tile } }

            append(level_entities, entity)
        }

        for tile in layer_instance.gridTiles {
            local_position := Vector2i32 {
                tile.px.x / grid_layer.gridSize,
                tile.px.y / grid_layer.gridSize,
            }
            source_position := Vector2i32 { tile.src[0], tile.src[1] }

            entity := entity_make(fmt.tprintf("Tile %v", local_position))
            entity_add_transform_grid(entity, local_position, grid_layer.gridSize)
            entity_add_sprite(entity, tileset_assets[tileset_uid], source_position, texture_padding = 1)
            _game.entities.components_flag[entity] = Component_Flag { { .Tile } }

            append(level_entities, entity)
        }

        grid := [dynamic]Grid_Cell {}
        if layer_index == LDTK_LAYER_GRID {
            for grid_value in layer_instance.intGridCsv {
                flags := int_grid_csv_to_flags(grid_value)
                append(&grid, flags)
            }
        }

        target_level^ = Level { target_level_id, target_level_position, target_level_size, tileset_uid, grid[:] }
    }

    {
        layer_instance := level.layerInstances[LDTK_LAYER_ENTITIES]

        entity_layer_index := -1
        for layer, i in data.defs.layers {
            if layer.uid == layer_instance.layerDefUid {
                entity_layer_index = i
                break
            }
        }
        assert(entity_layer_index > -1, fmt.tprintf("Can't find layer with uid: %v", layer_instance.layerDefUid))
        entity_layer := data.defs.layers[entity_layer_index]

        ldtk_entities := map[engine.LDTK_Entity_Uid]engine.LDTK_Entity {}
        for entity in data.defs.entities {
            ldtk_entities[entity.uid] = entity
        }

        for entity_instance in layer_instance.entityInstances {
            entity_def := ldtk_entities[entity_instance.defUid]

            local_position := Vector2i32 {
                entity_instance.px.x / entity_layer.gridSize,
                entity_instance.px.y / entity_layer.gridSize,
            }

            entity := entity_make(fmt.tprintf("Entity %v", entity_def.identifier))
            entity_add_transform_grid(entity, local_position, { entity_def.width, entity_def.height })
            // entity_add_sprite(entity, _game.asset_debug, { 24, 96 }, GRID_SIZE_V2, 1, 2)
            _game.entities.components_meta[entity] = Component_Meta { entity_def.uid }
            _game.ldtk_entity_defs[entity_def.uid] = entity_def

            append(level_entities, entity)
        }
    }

    return target_level^
}
