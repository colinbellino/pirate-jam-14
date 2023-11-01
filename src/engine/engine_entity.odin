package engine

import "core:fmt"
import "core:log"
import "core:math"
import "core:math/ease"
import "core:runtime"
import "core:slice"
import "core:strings"
import "core:container/queue"

Entity :: distinct u16
Component_Key :: distinct string

Entity_State :: struct {
    current_entity_id:          u16,
    entities:                   [dynamic]Entity,
    available_slots:            queue.Queue(u16),
    components:                 map[Component_Key]Component_List,
}

Component_List :: struct {
    type:           typeid,
    type_key:       Component_Key,
    data:           ^runtime.Raw_Dynamic_Array,
    entity_indices: map[Entity]i16,
}

Entity_Errors :: enum {
    None,
    Entity_Not_Found,
    Component_Not_Registered,
    Component_Not_Found,
    Component_Already_Added,
    Component_Already_Registered,
}

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

Component_Tile_Meta :: struct {
    entity_uid: LDTK_Entity_Uid,
}

entity_init :: proc() -> (ok: bool) {
    _e.entity = new(Entity_State)
    _e.entity.components = make(map[Component_Key]Component_List)
    return true
}

entity_create_entity :: proc {
    entity_create_entity_base,
    entity_create_entity_name,
}
entity_create_entity_name :: proc(name: string) -> Entity {
    context.allocator = _e.allocator
    entity := entity_create_entity_base()
    entity_set_component(entity, Component_Name { strings.clone(name) })
    return entity
}
entity_create_entity_base :: proc() -> Entity {
    context.allocator = _e.allocator
    if queue.len(_e.entity.available_slots) <= 0 {
      append_elem(&_e.entity.entities, Entity(_e.entity.current_entity_id))
      _e.entity.current_entity_id += 1
      return Entity(_e.entity.current_entity_id - 1)
    } else {
      entity_index := queue.pop_front(&_e.entity.available_slots)
      _e.entity.entities[entity_index] = Entity(entity_index)
      return Entity(entity_index)
    }

    return Entity(_e.entity.current_entity_id)
}

entity_register_component :: proc($type: typeid) -> Entity_Errors {
    type_key := _entity_type_to_key(type)
    exists := type_key in _e.entity.components
    if exists {
        return .Component_Already_Registered
    }

    array := new([dynamic]type)
    array^ = make_dynamic_array([dynamic]type)
    _e.entity.components[type_key] = {
        type = type,
        type_key = type_key,
        data = cast(^runtime.Raw_Dynamic_Array) array,
    }

    return .None
}

entity_get_component :: proc(entity: Entity, $type: typeid) -> (^type, Entity_Errors) {
    if entity_has_component(entity, type) == false {
        return nil, .Component_Not_Found
    }

    type_key := _entity_type_to_key(type)
    index, is_entity_a_key := _e.entity.components[type_key].entity_indices[entity]
    if is_entity_a_key == false {
        return nil, .Entity_Not_Found
    }

    array := cast(^[dynamic]type) _e.entity.components[type_key].data
    return &array[index], .None
}

entity_delete_entity :: proc(entity: Entity) {
    for type_key, component in &_e.entity.components {
        type := _entity_key_to_type(type_key)
        _remove_component_with_typeid(entity, type)
    }

    _e.entity.entities[u16(entity)] = {}
    queue.push_back(&_e.entity.available_slots, u16(entity))
}

entity_format :: proc(entity: Entity) -> string {
    component_name, err := entity_get_component(entity, Component_Name)
    if err == .None {
        return fmt.tprintf("%v (%v)", entity, component_name.name)
    }
    return fmt.tprintf("Unamed (%v)", entity)
}

entity_add_transform :: proc(entity: Entity, world_position: Vector2f32, scale: Vector2f32 = { 1, 1 }) -> ^Component_Transform {
    data := Component_Transform {
        position = world_position,
        scale = scale,
    }
    component_transform, _ := _entity_add_component(entity, data)
    return component_transform
}

entity_add_sprite :: proc(entity: Entity, texture_asset: Asset_Id, texture_position: Vector2i32 = { 0, 0 }, texture_size: Vector2i32, texture_padding: i32 = 0, z_index: i32 = 0, color: Color = { 1, 1, 1, 1 }) -> ^Component_Rendering {
    data := Component_Rendering {
        visible = true,
        texture_asset = texture_asset,
        texture_position = texture_position,
        texture_size = texture_size,
        texture_padding = texture_padding,
        z_index = z_index,
        color = color,
    }

    component_rendering, _ := _entity_add_component(entity, data)
    return component_rendering
}

entity_has_component :: proc(entity: Entity, type: typeid) -> bool {
    type_key := _entity_type_to_key(type)
    result := entity in _e.entity.components[type_key].entity_indices
    return result
}

entity_set_component :: proc(entity: Entity, component: $type) -> (err: Entity_Errors) {
    if entity_has_component(entity, type) == false {
        _, err := _entity_add_component(entity, type {})
        if err != .None {
            return err
        }
    }

    type_key := _entity_type_to_key(type)
    index, is_entity_a_key := _e.entity.components[type_key].entity_indices[entity]
    if is_entity_a_key == false {
        return .Component_Not_Found
    }

    array := cast(^[dynamic]type) _e.entity.components[type_key].data
    array[index] = component;

    return .None
}

// FIXME:
entity_get_entities_with_components :: proc(types: []typeid) -> (entities: [dynamic]Entity) {
    entities = make([dynamic]Entity)

    if len(types) <= 0 {
        return entities
    } else if len(types) == 1 {
        type_key := _entity_type_to_key(types[0])
        for entity, _ in _e.entity.components[type_key].entity_indices {
            append_elem(&entities, entity)
        }
        return entities
    }

    type_key := _entity_type_to_key(types[0])
    for entity, _ in _e.entity.components[type_key].entity_indices {
        has_all_components := true
        for comp_type in types[1:] {
            if entity_has_component(entity, comp_type) == false {
                has_all_components = false
                break
            }
        }

        if has_all_components {
            append_elem(&entities, entity)
        }
    }

    return entities
}
entity_get_components :: proc($type: typeid) -> ([]type, Entity_Errors) {
    array := cast(^[dynamic]type) _e.entity.components[type].data
    return array[:], .None
}

entity_get_entities_count       :: proc() -> int { return len(_e.entity.entities) - queue.len(_e.entity.available_slots) }
entity_get_entities             :: proc() -> []Entity { return _e.entity.entities[:entity_get_entities_count()] }

@(private="file")
_entity_add_component :: proc(entity: Entity, component: $type) -> (^type, Entity_Errors) {
    entity_register_component(type)

    if entity_has_component(entity, type) {
        return nil, .Component_Already_Added
    }

    type_key := _entity_type_to_key(type)
    array := cast(^[dynamic]type) _e.entity.components[type_key].data
    components := &_e.entity.components[type_key]

    append_elem(array, component)
    // Map the entity to the new index, so we can lookup the component index later,
    components.entity_indices[entity] = i16(len(array) - 1)

    return &array[components.entity_indices[entity]], .None
}

@(private="file")
_remove_component_with_typeid :: proc(entity: Entity, type: typeid) -> Entity_Errors {
    if entity_has_component(entity, type) == false {
        return .Component_Not_Found
    }

    type_key := _entity_type_to_key(type)
    index := _e.entity.components[type_key].entity_indices[entity]

    array_len := _e.entity.components[type_key].data^.len
    array := _e.entity.components[type_key].data^.data
    comp_map := _e.entity.components[type_key]

    info := type_info_of(type)
    struct_size := info.size
    array_in_bytes := slice.bytes_from_ptr(array, array_len * struct_size)

    byte_index := int(index) * struct_size
    last_byte_index := (len(array_in_bytes)) - struct_size
    e_index := comp_map.entity_indices[entity]
    e_back := i16(array_len - 1)
    if e_index != e_back {
        slice.swap_with_slice(array_in_bytes[byte_index: byte_index + struct_size], array_in_bytes[last_byte_index:])
        // TODO: Remove this and replace it with something that dosen't have to do a lot of searching.
        for _, value in &comp_map.entity_indices {
            if value == e_back {
                value = e_index
            }
        }
    }

    delete_key(&comp_map.entity_indices, entity)

    return .None
}

_entity_type_to_key :: proc(type: typeid) -> Component_Key {
    type_info := type_info_of(type)
    type_info_named, ok := type_info.variant.(runtime.Type_Info_Named)
    return cast(Component_Key) type_info_named.name
}

_entity_key_to_type :: proc(type_key: Component_Key) -> typeid {
    for index in _e.entity.components {
        component_list := _e.entity.components[index]
        if type_key == component_list.type_key {
            return component_list.type
        }
    }
    return nil
}
