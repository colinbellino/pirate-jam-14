package game

import "core:encoding/json"
import "core:fmt"
import "core:log"
import "core:math/linalg"
import "core:runtime"
import "core:slice"
import "core:strings"
import "../engine"

Level_Layers :: enum {
    Top,
    Entities,
    Decoration,
    Tiles,
    Grid,
}

Level :: struct {
    id:                 i32,
    position:           Vector2i32,
    tileset_uid:        engine.LDTK_Tileset_Uid,
    size:               Vector2i32,
    grid:               []Grid_Cell,
    ldtk_entity_defs:   map[engine.LDTK_Entity_Uid]engine.LDTK_Entity,
    entities:           [dynamic]Entity,
}
Grid_Cell :: bit_set[Grid_Cell_Flags]
Grid_Cell_Flags :: enum {
    None     = 0,
    Block    = 1 << 0,
    Walk     = 1 << 1,
    See      = 1 << 2,
}

LDTK_ENTITY_ID_PLAYER_SPAWN      :: 70
LDTK_ENTITY_ID_BUCKET_SPAWN      :: 142
LDTK_ENTITY_ID_ADVENTURER_SPAWN  :: 132
LDTK_ENTITY_ID_EXIT              :: 136
LDTK_ENTITY_ID_SLIME             :: 139
LDTK_ENTITY_ID_SLIME_SMALL       :: 156
LDTK_ENTITY_ID_MESS              :: 140
LDTK_ENTITY_ID_TORCH             :: 147
LDTK_ENTITY_ID_CHEST             :: 149
LDTK_ENTITY_ID_DOOR              :: 157

// update_grid_flags :: proc(level: ^Level) {
//     for grid_index := 0; grid_index < len(level.grid); grid_index += 1 {
//         cell_below, has_cell_below := get_cell_by_index_with_offset(level, grid_index, { 0, 1 })
//         if has_cell_below && .Climb in cell_below {
//             level.grid[grid_index] |= { .Grounded }
//         }

//         if is_see_through(level.grid[grid_index]) == false {
//             has_visible_neighbours := false
//             neighbours: for direction in CARDINAL_DIRECTIONS {
//                 neighbour_cell, neighbour_cell_found := get_cell_by_index_with_offset(level, grid_index, direction)
//                 if neighbour_cell_found == false {
//                     continue neighbours
//                 }
//                 if is_see_through(neighbour_cell^) {
//                     has_visible_neighbours = true
//                     break neighbours
//                 }
//             }

//             if has_visible_neighbours {
//                 level.grid[grid_index] |= { .Fog_Half }
//             }
//         }
//     }
// }

get_cell_at_position :: proc(level: ^Level, position: Vector2i32) -> (^Grid_Cell, bool) {
    below_index := engine.grid_position_to_index(position, level.size.x)
    if below_index < 0 || below_index >= len(level.grid) {
        return nil, false
    }
    return &_mem.game.play.levels[_mem.game.play.current_room_index].grid[below_index], true
}

get_cell_by_index_with_offset :: proc(level: ^Level, grid_index: int, offset: Vector2i32) -> (^Grid_Cell, bool) {
    position := engine.grid_index_to_position(grid_index, level.size)
    return get_cell_at_position(level, position + offset)
}

int_grid_csv_to_flags :: proc(grid_value: i32) -> (result: Grid_Cell) {
    switch grid_value {
        case 0: /* empty */ result = { .See, .Walk }
        case 4: /* wall  */ result = { .Block }
        // case 5: /* floor */ result = { .See }
    }
    return
}

load_level_assets :: proc(level_asset_info: engine.Asset_Info_Map) -> (level_assets: map[engine.LDTK_Tileset_Uid]engine.Asset_Id) {
    for tileset in level_asset_info.defs.tilesets {
        asset, asset_found := get_asset_from_ldtk_rel_path(tileset.relPath)
        if asset_found == false {
            log.errorf("Tileset asset not found: %s", tileset.relPath)
            continue
        }

        level_assets[tileset.uid] = asset.id
        // TODO: load/unload assets when loading/unloading level?
        // engine.asset_load(asset.id, engine.Asset_Load_Options_Image { engine.RENDERER_FILTER_NEAREST, engine.RENDERER_WRAP_CLAMP_TO_EDGE })
    }

    return
}

make_levels :: proc(root: ^engine.LDTK_Root, level_ids: []string, texture_padding: i32, allocator: runtime.Allocator) -> []^Level {
    result := make([dynamic]^Level, allocator)

    Entity_Temp :: struct {
        entity: Entity,
        entity_ref:      engine.LDTK_Entity_Ref,
        previous_ref:    engine.LDTK_Entity_Ref,
    }
    temp := make([dynamic]Entity_Temp, context.temp_allocator)

    for level_id, i in level_ids {
        target_level := new(Level, allocator)

        target_level_index := -1
        for level, i in root.levels {
            if level.identifier == level_id {
                target_level_index = i
                break
            }
        }
        assert(target_level_index > -1, fmt.tprintf("Couldn't find level with that identifier: %v", level_id))
        assert(target_level_index < len(root.levels), fmt.tprintf("Level out of bounds: %v / %v", target_level_index, len(root.levels)))
        level := root.levels[target_level_index]

        grid_found := false
        for layer, layer_index in root.defs.layers {
            layer_instance := level.layerInstances[layer_index]

            scale := GRID_SIZE / layer.gridSize // In case the grid size in the tilemap is different from the one we use in the game/renderer

            layer_def_index := -1
            for layer, i in root.defs.layers {
                if layer.uid == layer_instance.layerDefUid {
                    layer_def_index = i
                    break
                }
            }
            assert(layer_def_index > -1, fmt.tprintf("Can't find layer with uid: %v", layer_instance.layerDefUid))
            // layer_def := root.defs.layers[layer_def_index]

            target_level_id : i32 = i32(level.uid)
            target_level_size := Vector2i32 {
                level.pxWid / layer.gridSize,
                level.pxHei / layer.gridSize,
            }
            target_level_position := Vector2i32 {
                level.worldX / layer.gridSize,
                level.worldY / layer.gridSize,
            }

            if layer.tilesetDefUid > 0 {
                tileset_asset: ^engine.Asset
                for tileset in root.defs.tilesets {
                    if tileset.uid == layer.tilesetDefUid {
                        asset, asset_ok := get_asset_from_ldtk_rel_path(tileset.relPath)
                        if asset_ok {
                            tileset_asset = asset
                        }
                        break
                    }
                }
                assert(tileset_asset != nil, fmt.tprintf("tilset asset not found: %v", layer.tilesetDefUid))

                z_index := i32(len(Level_Layers) - layer_index)
                if Level_Layers(layer_index) == .Top {
                    z_index = 99
                }

                shader_asset := _mem.game.asset_shader_sprite
                for tile, i in layer_instance.autoLayerTiles {
                    local_position := Vector2i32 {
                        tile.px.x / layer.gridSize,
                        tile.px.y / layer.gridSize,
                    }
                    source_position := Vector2i32 { tile.src[0] * scale, tile.src[1] * scale }
                    position := grid_to_world_position_center(target_level_position + local_position)

                    entity := engine.entity_create_entity(fmt.aprintf("AutoTile %v (%v)", position, cast(Level_Layers) layer_index))
                    engine.entity_set_component(entity, engine.Component_Transform {
                        position = position,
                        scale = flip_to_scale(tile.f),
                    })
                    engine.entity_set_component(entity, engine.Component_Sprite {
                        texture_asset = tileset_asset.id,
                        texture_size = GRID_SIZE_V2,
                        texture_position = source_position,
                        texture_padding = texture_padding,
                        z_index = z_index,
                        tint = { 1, 1, 1, 1 },
                        shader_asset = shader_asset,
                    })
                    engine.entity_set_component(entity, Component_Collider {
                        box = { position.x - GRID_SIZE / 2, position.y - GRID_SIZE / 2, GRID_SIZE, GRID_SIZE },
                        type = { .Block },
                    })
                    engine.entity_set_component(entity, Component_Flag { { .Tile } })

                    append(&target_level.entities, entity)
                }

                for tile in layer_instance.gridTiles {
                    local_position := Vector2i32 {
                        tile.px.x / layer.gridSize,
                        tile.px.y / layer.gridSize,
                    }
                    source_position := Vector2i32 { tile.src[0] * scale, tile.src[1] * scale }
                    position := target_level_position + local_position

                    entity := engine.entity_create_entity(fmt.aprintf("GridTile %v (%v)", position, cast(Level_Layers) layer_index, allocator = allocator))
                    engine.entity_set_component(entity, engine.Component_Transform {
                        position = grid_to_world_position_center(position),
                        scale = flip_to_scale(tile.f),
                    })
                    engine.entity_set_component(entity, engine.Component_Sprite {
                        texture_asset = tileset_asset.id,
                        texture_size = GRID_SIZE_V2,
                        texture_position = source_position,
                        texture_padding = texture_padding,
                        z_index = z_index,
                        tint = { 1, 1, 1, 1 },
                        shader_asset = shader_asset,
                    })
                    engine.entity_set_component(entity, Component_Flag { { .Tile } })
                    append(&target_level.entities, entity)
                }

                flip_to_scale :: proc(flip: engine.LDTK_Flip) -> Vector2f32 {
                    if flip == 1 {
                        return { -1, +1 }
                    }
                    if flip == 2 {
                        return { +1, -1 }
                    }
                    if flip == 3 {
                        return { -1, -1 }
                    }
                    return { +1, +1 }
                }
            }

            grid := [dynamic]Grid_Cell {}
            if layer_index == int(Level_Layers.Grid) {
                assert(grid_found == false, "Can't have two intGridCsv.")
                for grid_value in layer_instance.intGridCsv {
                    flags := int_grid_csv_to_flags(grid_value)
                    append(&grid, flags)
                }
                grid_found = true
            }

            target_level.id          = target_level_id
            target_level.position    = target_level_position
            target_level.tileset_uid = layer.tilesetDefUid
            target_level.size        = target_level_size
            target_level.grid        = grid[:]
        }

        {
            layer_instance := level.layerInstances[int(Level_Layers.Entities)]

            entity_layer_index := -1
            for layer, i in root.defs.layers {
                if layer.uid == layer_instance.layerDefUid {
                    entity_layer_index = i
                    break
                }
            }
            assert(entity_layer_index > -1, fmt.tprintf("Can't find layer with uid: %v", layer_instance.layerDefUid))
            entity_layer := root.defs.layers[entity_layer_index]

            ldtk_entities := map[engine.LDTK_Entity_Uid]engine.LDTK_Entity {}
            for entity in root.defs.entities {
                ldtk_entities[entity.uid] = entity
            }
            target_level_position := Vector2i32 {
                level.worldX / entity_layer.gridSize,
                level.worldY / entity_layer.gridSize,
            }

            for entity_instance, i in layer_instance.entityInstances {
                entity_def := ldtk_entities[entity_instance.defUid]

                local_position := Vector2i32 {
                    entity_instance.px.x / entity_layer.gridSize,
                    entity_instance.px.y / entity_layer.gridSize,
                }
                position := grid_to_world_position_center(target_level_position + local_position, GRID_SIZE)

                field_instance_lit := false
                field_instance_opened := false
                field_instance_last_door := false
                field_instance_direction := Direction.East
                field_instance_point := Vector2i32 {}
                for field_instance, i in entity_instance.fieldInstances {
                    if field_instance.__type == "Bool" && field_instance.__identifier == "Lit" {
                        val, ok := field_instance.__value.(json.Boolean)
                        assert(ok, fmt.tprintf("couldn't parse field_instance: %v", field_instance))
                        field_instance_lit = val
                    }
                    if field_instance.__type == "Bool" && field_instance.__identifier == "Opened" {
                        val, ok := field_instance.__value.(json.Boolean)
                        assert(ok, fmt.tprintf("couldn't parse field_instance: %v", field_instance))
                        field_instance_opened = val
                    }
                    if field_instance.__type == "Bool" && field_instance.__identifier == "LastDoor" {
                        val, ok := field_instance.__value.(json.Boolean)
                        assert(ok, fmt.tprintf("couldn't parse field_instance: %v", field_instance))
                        field_instance_last_door = val
                    }
                    if field_instance.__type == "LocalEnum.Direction" && field_instance.__identifier == "Direction" {
                        val, ok := field_instance.__value.(json.String)
                        assert(ok, fmt.tprintf("couldn't parse field_instance: %v", field_instance))
                        if val == "East" { field_instance_direction = .East }
                        if val == "South" { field_instance_direction = .South }
                        if val == "West" { field_instance_direction = .West }
                        if val == "North" { field_instance_direction = .North }
                    }
                    if field_instance.__type == "Point" && field_instance.__identifier == "Point" {
                        val, ok := field_instance.__value.(json.Object)
                        assert(ok, fmt.tprintf("couldn't parse field_instance: %v", field_instance))
                        field_instance_point = { i32(val["cx"].(json.Integer)), i32(val["cy"].(json.Integer)) }
                    }
                }

                entity: Entity
                if entity_def.uid != 0 {
                    name := fmt.aprintf("%v %v", entity_def.identifier, position, allocator = allocator)

                    if entity_def.uid == LDTK_ENTITY_ID_SLIME {
                        entity = entity_create_slime(name, position)
                    } else if entity_def.uid == LDTK_ENTITY_ID_SLIME_SMALL {
                        entity = entity_create_slime(name, position, small = true)
                    } else if entity_def.uid == LDTK_ENTITY_ID_MESS {
                        entity = entity_create_mess(name, position)
                    } else if entity_def.uid == LDTK_ENTITY_ID_TORCH {
                        entity = entity_create_torch(name, position, field_instance_lit)
                    } else if entity_def.uid == LDTK_ENTITY_ID_CHEST {
                        entity = entity_create_chest(name, position)
                    } else if entity_def.uid == LDTK_ENTITY_ID_DOOR {
                        entity = entity_create_door(name, position, field_instance_opened, field_instance_direction, field_instance_last_door)
                    } else if entity_def.uid == LDTK_ENTITY_ID_EXIT {
                        direction := general_direction(auto_cast(linalg.array_cast(field_instance_point - local_position, f32)))
                        entity = entity_create_exit(name, position, direction)
                    } else {
                        entity = engine.entity_create_entity(name)
                        engine.entity_set_component(entity, engine.Component_Transform {
                            position = position,
                            scale = { 1, 1 },
                        })
                    }
                    engine.entity_set_component(entity, engine.Component_Tile_Meta { entity_uid = entity_def.uid })
                }

                if len(entity_instance.fieldInstances) > 0 {
                    for field_instance, i in entity_instance.fieldInstances {
                        if field_instance.__type == "EntityRef" {
                            val, ok := field_instance.__value.(json.Object)
                            assert(ok, fmt.tprintf("couldn't parse field_instance: %v", field_instance))
                            entity_ref := engine.LDTK_Entity_Ref {
                                entityIid = entity_instance.iid,
                                layerIid = layer_instance.iid,
                                levelIid = level.iid,
                                worldIid = root.iid,
                            }
                            previous_ref := engine.LDTK_Entity_Ref {
                                entityIid = val["entityIid"].(json.String),
                                layerIid = val["layerIid"].(json.String),
                                levelIid = val["levelIid"].(json.String),
                                worldIid = val["worldIid"].(json.String),
                            }
                            append(&temp, Entity_Temp { entity, entity_ref, previous_ref })
                        }
                    }
                }

                target_level.ldtk_entity_defs[entity_def.uid] = entity_def

                append(&target_level.entities, entity)
            }
        }

        append(&result, target_level)
    }

    for t, i in temp {
        previous_entity := Entity(0)
        for t2, i2 in temp {
            if t.previous_ref.entityIid == t2.entity_ref.entityIid {
                previous_entity = t2.entity
                break
            }
        }
        path := Component_Path { previous = previous_entity }
        engine.entity_set_component(t.entity, path)
        if previous_entity == Entity(0) {
            log.warnf("not found: %v", t)
        }
    }

    return result[:]
}

get_asset_from_ldtk_rel_path :: proc(maybe_rel_path: Maybe(string)) -> (asset: ^engine.Asset, asset_found: bool){
    rel_path, path_found := maybe_rel_path.?
    if path_found == false {
        return
    }

    path, path_ok := strings.replace(rel_path, "../art", "media/art", 1)
    if path_ok == false {
        log.warnf("Invalid path: %s", rel_path)
        return
    }

    asset, asset_found = engine.asset_get_by_file_name(path)
    return
}
