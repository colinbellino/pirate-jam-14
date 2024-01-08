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
    arena:              Named_Virtual_Arena,
    internal_arena:       Named_Virtual_Arena,
    // eveyrthing below is inside the internal_arena and can be cleared by users
    current_entity_id:  uint,
    entities:           [dynamic]Entity,
    available_slots:    queue.Queue(uint),
    components:         map[Component_Key]Component_List,
}

Entity :: distinct uint

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
    flip:               i8,
    shader_asset:       Asset_Id,
}

Component_Tile_Meta :: struct {
    entity_uid: LDTK_Entity_Uid,
}

Component_Animation :: struct {
    animation: ^Animation
}

ENTITY_ARENA_SIZE          :: mem.Kilobyte * 64
ENTITY_ARENA_SIZE_INTERNAL :: mem.Megabyte * 2
ENTITY_INVALID             :: Entity(0)
ENTITY_MAX                 :: 1024 * 4
COMPONENT_MAX              :: 32

@(private="file")
_entity: ^Entity_State

entity_init :: proc() -> (entity_state: ^Entity_State, ok: bool) #optional_ok {
    profiler_zone("entity_init")

    log.infof("Entity -----------------------------------------------------")
    defer log_ok(ok)

    _entity = mem_named_arena_virtual_bootstrap_new_or_panic(Entity_State, "arena", ENTITY_ARENA_SIZE, "entity")
    mem_make_named_arena(&_entity.internal_arena, "entity_internal", ENTITY_ARENA_SIZE_INTERNAL)
    entity_reset_memory()

    log.infof("  ENTITY_MAX:           %v", ENTITY_MAX)
    log.infof("  COMPONENT_MAX:        %v", COMPONENT_MAX)

    entity_state = _entity
    ok = true
    return
}

entity_reset_memory :: proc() {
    context.allocator = _entity.internal_arena.allocator

    for entity in _entity.entities {
        entity_delete_entity(entity)
    }

    clear(&_entity.entities)
    queue.clear(&_entity.available_slots)
    clear(&_entity.components)
    free_all(context.allocator)

    _entity.entities = make([dynamic]Entity)
    _entity.components = make(map[Component_Key]Component_List, COMPONENT_MAX)
    append(&_entity.entities, ENTITY_INVALID) // Entity 0 will always be invalid, so we can use it to check for invalid entities.
    _entity.current_entity_id = 1
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
    context.allocator = _entity.internal_arena.allocator
    entity := entity_create_entity_base()
    entity_set_component(entity, Component_Name { name })
    return entity
}
entity_create_entity_base :: proc() -> Entity {
    context.allocator = _entity.internal_arena.allocator

    reuse_existing := queue.len(_entity.available_slots) > 0
    if reuse_existing {
        entity_index := queue.pop_front(&_entity.available_slots)
        _entity.entities[entity_index] = Entity(entity_index)
        return Entity(entity_index)
    }

    assert(len(_entity.entities) < ENTITY_MAX, fmt.tprintf("max entities reached: %v", ENTITY_MAX))
    append_elem(&_entity.entities, Entity(_entity.current_entity_id))
    _entity.current_entity_id += 1
    return Entity(_entity.current_entity_id - 1)
}

entity_register_component :: proc($type: typeid) -> Entity_Errors {
    context.allocator = _entity.internal_arena.allocator
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
    context.allocator = _entity.internal_arena.allocator
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
    context.allocator = _entity.internal_arena.allocator

    component_name, component_name_err := entity_get_component(entity, Component_Name)
    if component_name_err == .None {
        delete(component_name.name)
    }

    component_animation, component_animation_err := entity_get_component(entity, Component_Animation)
    if component_animation_err == .None {
        animation_delete_animation(component_animation.animation)
    }

    for type_key, component_list in &_entity.components {
        type := _entity_key_to_type(type_key)
        _remove_component_with_typeid(entity, type)
    }

    _entity.entities[uint(entity)] = ENTITY_INVALID
    queue.push_front(&_entity.available_slots, uint(entity))
}
@(private="file")
_remove_component_with_typeid :: proc(entity: Entity, type: typeid) -> Entity_Errors {
    context.allocator = _entity.internal_arena.allocator
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
    context.allocator = _entity.internal_arena.allocator
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
    context.allocator = _entity.internal_arena.allocator
    type_key := _entity_type_to_key(type)
    result := entity in _entity.components[type_key].entity_indices
    return result
}

entity_set_component :: proc(entity: Entity, component: $type) -> (new_component: ^type, err: Entity_Errors) {
    context.allocator = _entity.internal_arena.allocator

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
    profiler_zone("entity_get_entities_with_components")
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
entity_get_components :: proc($type: typeid) -> ([]type, map[Entity]uint, Entity_Errors) {
    type_key := _entity_type_to_key(type)
    if type_key in _entity.components == false {
        return {}, {}, .None
    }
    array := cast(^[dynamic]type) _entity.components[type_key].data
    return array[:entity_get_entities_count()], _entity.components[type_key].entity_indices, .None
}

entity_get_entities_count       :: proc() -> int { return len(_entity.entities) - queue.len(_entity.available_slots) }
entity_get_entities             :: proc() -> []Entity { return _entity.entities[:entity_get_entities_count()] }

entity_get_components_by_entity :: proc($type: typeid, allocator := context.temp_allocator) -> []type {
    result := make([]type, len(_entity.entities), allocator)
    components, entity_indices, err := entity_get_components(type)
    assert(err == .None)
    for entity, component_index in entity_indices {
        result[entity] = components[component_index]
    }
    return result
}

@(private="file")
_entity_add_component :: proc(entity: Entity, component: $type) -> (^type, Entity_Errors) {
    context.allocator = _entity.internal_arena.allocator

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
    context.allocator = _entity.internal_arena.allocator
    type_info := type_info_of(type)
    type_info_named, ok := type_info.variant.(runtime.Type_Info_Named)
    return cast(Component_Key) type_info_named.name
}

_entity_key_to_type :: proc(type_key: Component_Key) -> typeid {
    context.allocator = _entity.internal_arena.allocator
    for index in _entity.components {
        component_list := _entity.components[index]
        if type_key == component_list.type_key {
            return component_list.type
        }
    }
    return nil
}
