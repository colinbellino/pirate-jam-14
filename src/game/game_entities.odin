package game

import "core:fmt"
import "core:log"
import "core:strings"
import "core:encoding/json"

import "../engine"

Meta_Value :: json.Value

Entity_Data :: struct {
    entities:                   [dynamic]Entity,
    // Notes: remember to add to entity_delete()
    components_name:            map[Entity]Component_Name,
    components_transform:       map[Entity]Component_Transform,
    components_rendering:       map[Entity]Component_Rendering,
    components_animation:       map[Entity]Component_Animation,
    components_flag:            map[Entity]Component_Flag,
    components_battle_info:     map[Entity]Component_Battle_Info,
    components_collision:       map[Entity]Component_Collision,
    components_meta:            map[Entity]Component_Meta,
}

Entity :: distinct u32

Component_Map :: map[Entity]Component

Component :: struct { }

Component_Name :: struct {
    name:               string,
}

Component_Transform :: struct {
    grid_position:      Vector2i32,
    world_position:     Vector2f32,
    size:               Vector2f32,
}

Component_Battle_Info :: struct {
    charge_time:        i32,
    charge_speed:       i32,
}

Component_Rendering :: struct {
    visible:            bool,
    texture_asset:      engine.Asset_Id,
    texture_position:   Vector2i32,
    texture_size:       Vector2i32,
    texture_padding:    i32,
    z_index:            i32,
}

Component_Animation :: struct {
    t:                  f32,
    speed:              f32,
    direction:          i8,
    revert:             bool,
    current_frame:      int,
    frames:             [dynamic]Vector2i32,
}

Component_Flag :: struct {
    value: Component_Flags,
}
Component_Flags :: bit_set[Component_Flags_Enum]
Component_Flags_Enum :: enum i32 {
    None,
    Interactive,
    Tile,
    Unit,
    Ally,
    Foe,
}

Component_Collision :: struct {
    rect:               engine.RectF32,
}

Component_Meta :: struct {
    entity_uid: engine.LDTK_Entity_Uid,
}

entity_delete :: proc(entity: Entity, entity_data: ^Entity_Data) {
    entity_index := -1
    for e, i in entity_data.entities {
        if e == entity {
            entity_index = i
            break
        }
    }
    if entity_index == -1 {
        log.errorf("Entity not found: %v", entity)
        return
    }

    // TODO: don't delete, disable & flag for reuse
    unordered_remove(&entity_data.entities, entity_index)

    delete_key(&entity_data.components_name, entity)
    delete_key(&entity_data.components_transform, entity)
    delete_key(&entity_data.components_rendering, entity)
    delete_key(&entity_data.components_animation, entity)
    delete_key(&entity_data.components_flag, entity)
    delete_key(&entity_data.components_battle_info, entity)
    delete_key(&entity_data.components_collision, entity)
    delete_key(&entity_data.components_meta, entity)
}

entity_format :: proc(entity: Entity, entity_data: ^Entity_Data) -> string {
    name := entity_data.components_name[entity].name
    return fmt.tprintf("%v (%v)", entity, name)
}

entity_make :: proc(name: string, allocator := context.allocator) -> Entity {
    entity := Entity(len(_game.entities.entities) + 1)
    append(&_game.entities.entities, entity)
    _game.entities.components_name[entity] = Component_Name { static_string(name, allocator) }
    // log.debugf("Entity created: %v", _game.entities.components_name[entity].name)
    return entity
}

entity_set_visibility :: proc(entity: Entity, value: bool, entity_data: ^Entity_Data) {
    (&entity_data.components_rendering[entity]).visible = value
}

entity_get_first_at_position :: proc(grid_position: Vector2i32, flag: Component_Flags_Enum, entity_data: ^Entity_Data) -> (found_entity: Entity, found: bool) {
    for entity, component_position in entity_data.components_transform {
        component_flag, has_flag := entity_data.components_flag[entity]
        if component_position.grid_position == grid_position && has_flag && flag in component_flag.value {
            found_entity = entity
            found = true
            return
        }
    }

    return
}

entity_add_transform :: proc(entity: Entity, world_position: Vector2f32, size: Vector2f32 = { f32(GRID_SIZE), f32(GRID_SIZE) }) {
    component_position := Component_Transform {}
    component_position.grid_position = { i32(world_position.x) / GRID_SIZE, i32(world_position.y) / GRID_SIZE }
    component_position.world_position = world_position
    component_position.size = size
    _game.entities.components_transform[entity] = component_position
}

entity_add_transform_grid :: proc(entity: Entity, grid_position: Vector2i32, size: Vector2i32) {
    component_position := Component_Transform {}
    component_position.grid_position = grid_position
    component_position.world_position = engine.vector_i32_to_f32(grid_position) * GRID_SIZE + engine.vector_i32_to_f32(size) / 2
    component_position.size = engine.vector_i32_to_f32(size)
    _game.entities.components_transform[entity] = component_position
}

entity_add_sprite :: proc(entity: Entity, texture_asset: engine.Asset_Id, texture_position: Vector2i32, texture_size: Vector2i32, texture_padding: i32 = 0, z_index: i32 = 0) {
    component_rendering := Component_Rendering {}
    component_rendering.visible = true
    component_rendering.texture_asset = texture_asset
    component_rendering.texture_position = texture_position
    component_rendering.texture_size = texture_size
    component_rendering.texture_padding = texture_padding
    component_rendering.z_index = z_index
    _game.entities.components_rendering[entity] = component_rendering
}

entity_has_flag :: proc(entity: Entity, flag: Component_Flags_Enum) -> bool {
    component_flag, has_flag := _game.entities.components_flag[entity]
    return has_flag && flag in component_flag.value
}

entity_create_unit :: proc(name: string, grid_position: Vector2i32) -> Entity {
    entity := entity_make(name)
    entity_add_transform_grid(entity, grid_position, { 8, 8 })
    entity_add_sprite(entity, 3, { 4 * 8, 15 * 8 }, { 8, 8 }, 1, 1)
    _game.entities.components_flag[entity] = { { .Unit } }
    return entity
}

// We don't want to use string literals since they are built into the binary and we want to avoid this when using code reload
// TODO: cache and reuse strings
static_string :: proc(str: string, allocator := context.allocator) -> string {
    return strings.clone(str, allocator)
}
