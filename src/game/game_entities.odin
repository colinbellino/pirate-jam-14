package game

import "core:encoding/json"
import "core:fmt"
import "core:log"
import "core:math"
import "core:strings"
import "core:testing"

import "../engine"

Entity :: engine.Entity

// TODO: move this to engine
Entity_State :: struct {
    entities:                   [dynamic]Entity,
    // Notes: remember to add to entity_delete()
    components_name:            map[Entity]engine.Component_Name,
    components_transform:       map[Entity]engine.Component_Transform,
    components_rendering:       map[Entity]engine.Component_Rendering,
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
    entity_uid: engine.LDTK_Entity_Uid,
}

entity_delete :: proc(state: ^Entity_State, entity: Entity) {
    entity_index := -1
    for e, i in state.entities {
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
    unordered_remove(&state.entities, entity_index)

    delete_key(&state.components_name, entity)
    delete_key(&state.components_transform, entity)
    delete_key(&state.components_rendering, entity)
    delete_key(&state.components_limbs, entity)
    delete_key(&state.components_flag, entity)
    delete_key(&state.components_meta, entity)
}

entity_format :: proc(state: ^Entity_State, entity: Entity) -> string {
    name := state.components_name[entity].name
    return fmt.tprintf("%v (%v)", entity, name)
}

entity_make :: proc(state: ^Entity_State, name: string, allocator := context.allocator) -> Entity {
    entity := Entity(len(state.entities) + 1)
    append(&state.entities, entity)
    state.components_name[entity] = engine.Component_Name { static_string(name, allocator) }
    // log.debugf("Entity created: %v", state.components_name[entity].name)
    return entity
}

entity_set_visibility :: proc(state: ^Entity_State, entity: Entity, value: bool) {
    (&state.components_rendering[entity]).visible = value
}

entity_add_transform :: proc(state: ^Entity_State, entity: Entity, world_position: Vector2f32, scale: Vector2f32 = { 1, 1 }) {
    component_transform := engine.Component_Transform {}
    component_transform.position = world_position
    component_transform.scale = scale
    state.components_transform[entity] = component_transform
}

entity_add_transform_grid :: proc(state: ^Entity_State, entity: Entity, grid_position: Vector2i32, scale: Vector2f32 = { 1, 1 }) {
    component_transform := engine.Component_Transform {}
    component_transform.position = grid_to_world_position_center(grid_position, GRID_SIZE)
    component_transform.scale = scale
    state.components_transform[entity] = component_transform
}

entity_add_sprite :: proc(state: ^Entity_State, entity: Entity, texture_asset: engine.Asset_Id, texture_position: Vector2i32 = { 0, 0 }, texture_size: Vector2i32 = GRID_SIZE_V2, texture_padding: i32 = 0, z_index: i32 = 0, color: Color = { 1, 1, 1, 1 }) {
    component_rendering := engine.Component_Rendering {}
    component_rendering.visible = true
    component_rendering.texture_asset = texture_asset
    component_rendering.texture_position = texture_position
    component_rendering.texture_size = texture_size
    component_rendering.texture_padding = texture_padding
    component_rendering.z_index = z_index
    component_rendering.color = color
    state.components_rendering[entity] = component_rendering
}

entity_has_flag :: proc(state: ^Entity_State, entity: Entity, flag: Component_Flags_Enum) -> bool {
    component_flag, has_flag := state.components_flag[entity]
    return has_flag && flag in component_flag.value
}

entity_create_unit :: proc(state: ^Entity_State, unit: ^Unit) -> Entity {
    SPRITE_SIZE :: Vector2i32 { 8, 8 }

    entity := entity_make(state, unit.name)

    hand_left  := entity_make(state, fmt.tprintf("%s: Hand (left)", unit.name))
    entity_add_transform(state, hand_left, { 0, 0 })
    (&state.components_transform[hand_left]).parent = entity
    entity_add_sprite(state, hand_left, 3, { 5, 15 } * GRID_SIZE_V2, SPRITE_SIZE, 1, z_index = 3)

    hand_right := entity_make(state, fmt.tprintf("%s: Hand (right)", unit.name))
    entity_add_transform(state, hand_right, { 0, 0 })
    (&state.components_transform[hand_right]).parent = entity
    entity_add_sprite(state, hand_right, 3, { 6, 15 } * GRID_SIZE_V2, SPRITE_SIZE, 1, z_index = 1)

    entity_add_transform_grid(state, entity, unit.grid_position)
    (&state.components_transform[entity]).scale.x *= f32(unit.direction)
    entity_add_sprite(state, entity, 3, unit.sprite_position * GRID_SIZE_V2, SPRITE_SIZE, 1, z_index = 2)
    state.components_flag[entity] = { { .Unit } }
    state.components_limbs[entity] = { hand_left = hand_left, hand_right = hand_right }

    return entity
}

entity_move_grid :: proc(state: ^Entity_State, entity: Entity, grid_position: Vector2i32) {
    component_transform := entity_get_component_transform(state, entity)
    component_transform.position = grid_to_world_position_center(grid_position, GRID_SIZE)
}

unit_move :: proc(state: ^Entity_State, unit: ^Unit, grid_position: Vector2i32) {
    component_transform := entity_get_component_transform(state, unit.entity)
    component_transform.position = grid_to_world_position_center(grid_position, GRID_SIZE)
}


entity_get_component_limbs      :: proc(state: ^Entity_State, entity: Entity) -> (^Component_Limbs, bool)            #optional_ok { return &state.components_limbs[entity] }
entity_get_component_transform  :: proc(state: ^Entity_State, entity: Entity) -> (^engine.Component_Transform, bool) #optional_ok { return &state.components_transform[entity] }
entity_get_component_rendering  :: proc(state: ^Entity_State, entity: Entity) -> (^engine.Component_Rendering, bool) #optional_ok { return &state.components_rendering[entity] }
entity_get_component_flag       :: proc(state: ^Entity_State, entity: Entity) -> (^Component_Flag, bool)             #optional_ok { return &state.components_flag[entity] }
entity_get_component_meta       :: proc(state: ^Entity_State, entity: Entity) -> (^Component_Meta, bool)             #optional_ok { return &state.components_meta[entity] }
entity_get_component_name       :: proc(state: ^Entity_State, entity: Entity) -> (^engine.Component_Name, bool)      #optional_ok { return &state.components_name[entity] }

entity_get_components_rendering :: proc(state: ^Entity_State) -> ^map[Entity]engine.Component_Rendering { return &state.components_rendering }

entity_set_component_flag       :: proc(state: ^Entity_State, entity: Entity, data: Component_Flag) { state.components_flag[entity] = data }
entity_set_component_meta       :: proc(state: ^Entity_State, entity: Entity, data: Component_Meta) { state.components_meta[entity] = data }

entity_get_entities_count       :: proc(state: ^Entity_State) -> int { return len(state.entities) }
entity_get_entities             :: proc(state: ^Entity_State) -> []Entity { return state.entities[:] }

//

// We don't want to use string literals since they are built into the binary and we want to avoid this when using code reload
// TODO: cache and reuse strings
// FIXME: make sure we actually need this now
static_string :: proc(str: string, allocator := context.allocator) -> string {
    return strings.clone(str, allocator)
}

grid_to_world_position_center :: proc(grid_position: Vector2i32, size: Vector2i32 = GRID_SIZE_V2) -> Vector2f32 {
    return Vector2f32 {
        f32(grid_position.x * GRID_SIZE + size.x / 2),
        f32(grid_position.y * GRID_SIZE + size.y / 2),
    }
}
world_to_grid_position :: proc(world_position: Vector2f32) -> Vector2i32 {
    x := f32(world_position.x / GRID_SIZE)
    y := f32(world_position.y / GRID_SIZE)
    return Vector2i32 {
        x >= 0 ? i32(x) : i32(math.ceil(x - 1)),
        y >= 0 ? i32(y) : i32(math.ceil(y - 1)),
    }
}
grid_position :: proc(x, y: i32) -> Vector2i32 {
    return { x, y } * GRID_SIZE_V2
}
