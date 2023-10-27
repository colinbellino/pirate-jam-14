package engine

import "core:math"
import "core:math/ease"
import "core:slice"
import "core:strings"
import "core:log"
import "core:fmt"

Entity :: distinct u32

Component_Name :: struct {
    name:               string,
}

Component_Transform :: struct {
    parent:             Entity,
    position:           Vector2f32,
    scale:              Vector2f32,
    // rotation:           f32,
}

Component_Rendering :: struct {
    visible:            bool,
    texture_asset:      Asset_Id,
    texture_position:   Vector2i32,
    texture_size:       Vector2i32,
    texture_padding:    i32,
    z_index:            i32,
    color:              Color,
}

Entity_State :: struct {
    entities:                   [dynamic]Entity,
    // Notes: remember to add to entity_delete()
    components_name:            map[Entity]Component_Name,
    components_transform:       map[Entity]Component_Transform,
    components_rendering:       map[Entity]Component_Rendering,
    components_limbs:           map[Entity]Component_Limbs,
    components_flag:            map[Entity]Component_Flag,
    components_meta:            map[Entity]Component_Meta,
}

Component_Limbs :: struct {
    hand_left: Entity,
    hand_right: Entity,
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

Component_Meta :: struct {
    entity_uid: LDTK_Entity_Uid,
}

entity_init :: proc() -> (ok: bool) {
    _e.entity = new(Entity_State)
    return true
}

entity_delete :: proc(entity: Entity) {
    entity_index := -1
    for e, i in _e.entity.entities {
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
    unordered_remove(&_e.entity.entities, entity_index)

    delete_key(&_e.entity.components_name, entity)
    delete_key(&_e.entity.components_transform, entity)
    delete_key(&_e.entity.components_rendering, entity)
    delete_key(&_e.entity.components_limbs, entity)
    delete_key(&_e.entity.components_flag, entity)
    delete_key(&_e.entity.components_meta, entity)
}

entity_format :: proc(entity: Entity) -> string {
    name := _e.entity.components_name[entity].name
    return fmt.tprintf("%v (%v)", entity, name)
}

entity_make :: proc(name: string, allocator := context.allocator) -> Entity {
    entity := Entity(len(_e.entity.entities) + 1)
    append(&_e.entity.entities, entity)
    _e.entity.components_name[entity] = Component_Name { strings.clone(name, allocator) }
    // log.debugf("Entity created: %v", _e.entity.components_name[entity].name)
    return entity
}

entity_set_visibility :: proc(entity: Entity, value: bool) {
    (&_e.entity.components_rendering[entity]).visible = value
}

entity_add_transform :: proc(entity: Entity, world_position: Vector2f32, scale: Vector2f32 = { 1, 1 }) -> ^Component_Transform {
    component_transform := Component_Transform {}
    component_transform.position = world_position
    component_transform.scale = scale
    _e.entity.components_transform[entity] = component_transform
    return &_e.entity.components_transform[entity]
}

entity_add_sprite :: proc(entity: Entity, texture_asset: Asset_Id, texture_position: Vector2i32 = { 0, 0 }, texture_size: Vector2i32, texture_padding: i32 = 0, z_index: i32 = 0, color: Color = { 1, 1, 1, 1 }) {
    component_rendering := Component_Rendering {}
    component_rendering.visible = true
    component_rendering.texture_asset = texture_asset
    component_rendering.texture_position = texture_position
    component_rendering.texture_size = texture_size
    component_rendering.texture_padding = texture_padding
    component_rendering.z_index = z_index
    component_rendering.color = color
    _e.entity.components_rendering[entity] = component_rendering
}

entity_has_flag :: proc(entity: Entity, flag: Component_Flags_Enum) -> bool {
    component_flag, has_flag := _e.entity.components_flag[entity]
    return has_flag && flag in component_flag.value
}

entity_get_component_limbs      :: proc(entity: Entity) -> (^Component_Limbs, bool)     #optional_ok { return &_e.entity.components_limbs[entity] }
entity_get_component_transform  :: proc(entity: Entity) -> (^Component_Transform, bool) #optional_ok { return &_e.entity.components_transform[entity] }
entity_get_component_rendering  :: proc(entity: Entity) -> (^Component_Rendering, bool) #optional_ok { return &_e.entity.components_rendering[entity] }
entity_get_component_flag       :: proc(entity: Entity) -> (^Component_Flag, bool)      #optional_ok { return &_e.entity.components_flag[entity] }
entity_get_component_meta       :: proc(entity: Entity) -> (^Component_Meta, bool)      #optional_ok { return &_e.entity.components_meta[entity] }
entity_get_component_name       :: proc(entity: Entity) -> (^Component_Name, bool)      #optional_ok { return &_e.entity.components_name[entity] }

entity_get_components_rendering :: proc() -> ^map[Entity]Component_Rendering { return &_e.entity.components_rendering }

entity_set_component_flag       :: proc(entity: Entity, data: Component_Flag) { _e.entity.components_flag[entity] = data }
entity_set_component_limbs      :: proc(entity: Entity, data: Component_Limbs) { _e.entity.components_limbs[entity] = data }
entity_set_component_meta       :: proc(entity: Entity, data: Component_Meta) { _e.entity.components_meta[entity] = data }

entity_get_entities_count       :: proc() -> int { return len(_e.entity.entities) }
entity_get_entities             :: proc() -> []Entity { return _e.entity.entities[:] }
