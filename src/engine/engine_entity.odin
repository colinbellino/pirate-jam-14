package engine

import "core:container/queue"
import "core:fmt"
import "core:log"
import "core:math"
import "core:math/ease"
import "core:mem"
import "core:runtime"
import "core:slice"
import "core:strings"

Entity_State :: struct {
    allocator:          mem.Allocator,
    current_entity_id:  uint,
    entities:           [dynamic]Entity,
    available_slots:    queue.Queue(uint),
    components:         map[Component_Key]Component_List,
}

Entity       :: distinct uint

Component_Key :: distinct string
Component_List :: struct {
    type:               typeid,
    type_key:           Component_Key,
    data:               ^runtime.Raw_Dynamic_Array,
    entity_indices:     map[Entity]uint,
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

Component_Sprite :: struct {
    hidden:             bool,
    texture_asset:      Asset_Id,
    texture_position:   Vector2i32,
    texture_size:       Vector2i32,
    texture_padding:    i32,
    z_index:            i32,
    tint:               Color,
    palette:            i32, // 0: no palette, 1-4: palette index to use
}

Component_Tile_Meta :: struct {
    entity_uid: LDTK_Entity_Uid,
}

ENTITY_ARENA_SIZE :: mem.Megabyte
ENTITY_INVALID    :: Entity(0)
ENTITY_MAX        :: 1024

@(private="file")
_entity: ^Entity_State

entity_init :: proc(allocator := context.allocator) -> (entity_state: ^Entity_State, ok: bool) #optional_ok {
    profiler_zone("entity_init")
    context.allocator = allocator

    log.infof("Entity -----------------------------------------------------")
    defer log_ok(ok)

    _entity = new(Entity_State)
    _entity.allocator = platform_make_named_arena_allocator("entity", ENTITY_ARENA_SIZE, runtime.default_allocator())
    _entity.entities = make([dynamic]Entity)
    _entity.components = make(map[Component_Key]Component_List, ENTITY_MAX)
    _entity.current_entity_id = 1
    append(&_entity.entities, ENTITY_INVALID) // Entity 0 will always be invalid, so we can use it to check for invalid entities.

    log.infof("  ENTITY_MAX:           %t", ENTITY_MAX)

    entity_state = _entity
    ok = true
    return
}

entity_reload :: proc(entity_state: ^Entity_State) {
    assert(entity_state != nil)
    _entity = entity_state
}

entity_create_entity :: proc {
    entity_create_entity_base,
    entity_create_entity_name,
}
entity_create_entity_name :: proc(name: string) -> Entity {
    context.allocator = _entity.allocator
    entity := entity_create_entity_base()
    entity_set_component(entity, Component_Name { strings.clone(name) })
    return entity
}
entity_create_entity_base :: proc() -> Entity {
    context.allocator = _entity.allocator
    if queue.len(_entity.available_slots) <= 0 {
        assert(len(_entity.entities) < ENTITY_MAX)
        append_elem(&_entity.entities, Entity(_entity.current_entity_id))
        _entity.current_entity_id += 1
        return Entity(_entity.current_entity_id - 1)
    } else {
        entity_index := queue.pop_front(&_entity.available_slots)
        _entity.entities[entity_index] = Entity(entity_index)
        return Entity(entity_index)
    }

    return Entity(_entity.current_entity_id)
}

entity_register_component :: proc($type: typeid) -> Entity_Errors {
    context.allocator = _entity.allocator
    type_key := _entity_type_to_key(type)
    exists := type_key in _entity.components
    if exists {
        return .Component_Already_Registered
    }

    array := new([dynamic]type)
    array^ = make_dynamic_array([dynamic]type)
    reserve(array, ENTITY_MAX)
    component_list := Component_List {
        type = type,
        type_key = type_key,
        data = cast(^runtime.Raw_Dynamic_Array) array,
    }
    _entity.components[type_key] = component_list

    return .None
}

entity_get_component :: proc(entity: Entity, $type: typeid) -> (^type, Entity_Errors) {
    context.allocator = _entity.allocator
    if entity_has_component(entity, type) == false {
        return nil, .Component_Not_Found
    }

    type_key := _entity_type_to_key(type)
    components := _entity.components[type_key]
    index, is_entity_a_key := components.entity_indices[entity]
    if is_entity_a_key == false {
        return nil, .Entity_Not_Found
    }

    components_array := cast(^[dynamic]type) components.data
    return &components_array[index], .None
}

entity_delete_entity :: proc(entity: Entity) {
    context.allocator = _entity.allocator
    for type_key, component_list in &_entity.components {
        type := _entity_key_to_type(type_key)
        _remove_component_with_typeid(entity, type)
    }

    _entity.entities[uint(entity)] = ENTITY_INVALID
    queue.push_back(&_entity.available_slots, uint(entity))
}
@(private="file")
_remove_component_with_typeid :: proc(entity: Entity, type: typeid) -> Entity_Errors {
    context.allocator = _entity.allocator
    if entity_has_component(entity, type) == false {
        return .Component_Not_Found
    }

    type_key := _entity_type_to_key(type)
    index := _entity.components[type_key].entity_indices[entity]

    components := _entity.components[type_key]
    components_array := _entity.components[type_key].data^.data
    components_len := _entity.components[type_key].data^.len

    info := type_info_of(type)
    struct_size := info.size
    array_in_bytes := slice.bytes_from_ptr(components_array, components_len * struct_size)

    byte_index := int(index) * struct_size
    last_byte_index := len(array_in_bytes) - struct_size
    entity_index := components.entity_indices[entity]
    entity_back := uint(components_len - 1)
    if entity_index != entity_back {
        slice.swap_with_slice(array_in_bytes[byte_index: byte_index + struct_size], array_in_bytes[last_byte_index:])
        // TODO: Remove this and replace it with something that doesn't have to do a lot of searching.
        for _, value in &components.entity_indices {
            if value == entity_back {
                value = entity_index
            }
        }
    }

    delete_key(&components.entity_indices, entity)

    return .None
}

entity_get_name :: proc(entity: Entity) -> string {
    context.allocator = _entity.allocator
    if entity == Entity(0) {
        return "<Invalid>"
    }
    component_name, err := entity_get_component(entity, Component_Name)
    if err == .None {
        return component_name.name
    }
    return "<Unamed>"
}

entity_format :: proc(entity: Entity) -> string {
    return fmt.tprintf("%v (%v)", entity, entity_get_name(entity))
}

entity_has_component :: proc(entity: Entity, type: typeid) -> bool {
    context.allocator = _entity.allocator
    type_key := _entity_type_to_key(type)
    result := entity in _entity.components[type_key].entity_indices
    return result
}

entity_set_component :: proc(entity: Entity, component: $type) -> (new_component: ^type, err: Entity_Errors) {
    context.allocator = _entity.allocator

    if entity_has_component(entity, type) == false {
        _, err := _entity_add_component(entity, type {})
        if err != .None {
            return nil, err
        }
    }

    type_key := _entity_type_to_key(type)
    index, is_entity_a_key := _entity.components[type_key].entity_indices[entity]
    if is_entity_a_key == false {
        return nil, .Component_Not_Found
    }

    components_array := cast(^[dynamic]type) _entity.components[type_key].data
    components_array[index] = component

    return &components_array[index], .None
}

// FIXME: this is slow
entity_get_entities_with_components :: proc(types: []typeid, allocator := context.allocator) -> (entities: [dynamic]Entity) {
    context.allocator = allocator
    entities = make([dynamic]Entity)

    if len(types) <= 0 {
        return entities
    } else if len(types) == 1 {
        type_key := _entity_type_to_key(types[0])
        for entity, _ in _entity.components[type_key].entity_indices {
            append_elem(&entities, entity)
        }
        return entities
    }

    type_key := _entity_type_to_key(types[0])
    for entity, _ in _entity.components[type_key].entity_indices {
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
    array := cast(^[dynamic]type) _entity.components[type].data
    return array[:], .None
}

entity_get_entities_count       :: proc() -> int { return len(_entity.entities) - queue.len(_entity.available_slots) }
entity_get_entities             :: proc() -> []Entity { return _entity.entities[:entity_get_entities_count()] }

@(private="file")
_entity_add_component :: proc(entity: Entity, component: $type) -> (^type, Entity_Errors) {
    context.allocator = _entity.allocator

    entity_register_component(type)

    if entity_has_component(entity, type) {
        return nil, .Component_Already_Added
    }

    type_key := _entity_type_to_key(type)
    components_array := cast(^[dynamic]type) _entity.components[type_key].data
    components := &_entity.components[type_key]

    append_elem(components_array, component)
    // Map the entity to the new index, so we can lookup the component index later,
    components.entity_indices[entity] = len(components_array) - 1

    index := components.entity_indices[entity]
    return &components_array[index], .None
}

_entity_type_to_key :: proc(type: typeid) -> Component_Key {
    context.allocator = _entity.allocator
    type_info := type_info_of(type)
    type_info_named, ok := type_info.variant.(runtime.Type_Info_Named)
    return cast(Component_Key) type_info_named.name
}

_entity_key_to_type :: proc(type_key: Component_Key) -> typeid {
    context.allocator = _entity.allocator
    for index in _entity.components {
        component_list := _entity.components[index]
        if type_key == component_list.type_key {
            return component_list.type
        }
    }
    return nil
}
