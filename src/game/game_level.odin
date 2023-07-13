package game

import "core:fmt"

import "../engine"

LDTK_LAYER_ENTITIES     :: 0
LDTK_LAYER_TILES        :: 1
LDTK_LAYER_GRID         :: 2

Level :: struct {
    id:                 i32,
    position:           Vector2i32,
    size:               Vector2i32,
    tileset_uid:        engine.LDTK_Tileset_Uid,
}

make_level :: proc(data: ^engine.LDTK_Root, target_level_index: int, tileset_assets: map[engine.LDTK_Tileset_Uid]engine.Asset_Id, allocator := context.allocator) -> (Level, [dynamic]Entity) {
    context.allocator = allocator

    entities := make([dynamic]Entity, _game.game_mode.allocator)
    target_level := new(Level, _game.game_mode.allocator)

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

            entity := entity_make(fmt.tprintf("AutoTile %v", local_position))
            entity_add_transform(entity, local_position, { f32(grid_layer.gridSize), f32(grid_layer.gridSize) })
            entity_add_sprite(entity, tileset_assets[tileset_uid], source_position, GRID_SIZE_V2, tile.f)
            _game.entities.components_z_index[entity] = Component_Z_Index { 0 }
            _game.entities.components_flag[entity] = Component_Flag { { .Tile } }

            append(&entities, entity)
        }

        for tile in layer_instance.gridTiles {
            local_position := Vector2i32 {
                tile.px.x / grid_layer.gridSize,
                tile.px.y / grid_layer.gridSize,
            }
            source_position := Vector2i32 { tile.src[0], tile.src[1] }

            entity := entity_make(fmt.tprintf("Tile %v", local_position))
            entity_add_transform(entity, local_position, { f32(grid_layer.gridSize), f32(grid_layer.gridSize) })
            entity_add_sprite(entity, tileset_assets[tileset_uid], source_position, GRID_SIZE_V2, tile.f)
            _game.entities.components_z_index[entity] = Component_Z_Index { 1 }
            _game.entities.components_flag[entity] = Component_Flag { { .Tile } }

            append(&entities, entity)
        }

        target_level^ = Level { target_level_id, target_level_position, target_level_size, tileset_uid }
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

        // target_level_position := Vector2i32 {
        //     level.worldX / entity_layer.gridSize,
        //     level.worldY / entity_layer.gridSize,
        // }

        ldtk_entities := map[engine.LDTK_Entity_Uid]engine.LDTK_Entity {}
        for entity in data.defs.entities {
            ldtk_entities[entity.uid] = entity
            // log.debug("entity: %s", entity)
        }

        for entity_instance in layer_instance.entityInstances {
            entity_def := ldtk_entities[entity_instance.defUid]
            // log.debug("entity: %s", entity_def)

            local_position := Vector2i32 {
                entity_instance.px.x / entity_layer.gridSize,
                entity_instance.px.y / entity_layer.gridSize,
            }
            grid_position := local_position
            // source_position := Vector2i32 { entity_instance.width, entity_instance.height }

            entity := entity_make(fmt.tprintf("Entity %v", entity_def.identifier))
            entity_add_transform(entity, grid_position, { f32(entity_def.width), f32(entity_def.height) })
            _game.entities.components_flag[entity] = Component_Flag { { .Interactive } }
            for field_instance in entity_instance.fieldInstances {
                if field_instance.__value != nil {
                    entity_add_meta(entity, field_instance.__identifier, field_instance.__value)
                }
            }

            append(&entities, entity)
        }
    }

    return target_level^, entities
}
