package game

import "core:encoding/json"
import "core:fmt"
import "core:log"
import "core:math"
import "core:strings"
import "core:testing"

import "../engine"

Meta_Value :: json.Value

Entity_Data :: struct {
    entities:                   [dynamic]Entity,
    // Notes: remember to add to entity_delete()
    components_name:            map[Entity]Component_Name,
    components_transform:       map[Entity]Component_Transform,
    components_rendering:       map[Entity]Component_Rendering,
    components_animation:       map[Entity]Component_Animation,
    components_limbs:           map[Entity]Component_Limbs,
    components_flag:            map[Entity]Component_Flag,
    components_meta:            map[Entity]Component_Meta,
}

Entity :: distinct u32

Component_Map :: map[Entity]Component

Component :: struct { }

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
    texture_asset:      engine.Asset_Id,
    texture_position:   Vector2i32,
    texture_size:       Vector2i32,
    texture_padding:    i32,
    z_index:            i32,
    color:              Color,
}

Component_Animation :: struct {
    running:        bool,
    looping:        bool,
    t:              f32,
    speed:          f32,
    steps_position: [dynamic]engine.Animation_Step(Vector2f32),
    steps_scale:    [dynamic]engine.Animation_Step(Vector2f32),
    steps_sprite:   [dynamic]engine.Animation_Step(i8),
    steps_color:    [dynamic]engine.Animation_Step(Vector4f32),
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
    delete_key(&entity_data.components_limbs, entity)
    delete_key(&entity_data.components_flag, entity)
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

// entity_get_first_at_position :: proc(grid_position: Vector2i32, flag: Component_Flags_Enum, entity_data: ^Entity_Data) -> (found_entity: Entity, found: bool) {
//     for entity, component_transform in entity_data.components_transform {
//         component_flag, has_flag := entity_data.components_flag[entity]
//         if component_transform.grid_position == grid_position && has_flag && flag in component_flag.value {
//             found_entity = entity
//             found = true
//             return
//         }
//     }

//     return
// }

entity_add_transform :: proc(entity: Entity, world_position: Vector2f32, scale: Vector2f32 = { 1, 1 }) {
    component_transform := Component_Transform {}
    component_transform.position = world_position
    component_transform.scale = scale
    _game.entities.components_transform[entity] = component_transform
}

entity_add_transform_grid :: proc(entity: Entity, grid_position: Vector2i32, scale: Vector2f32 = { 1, 1 }) {
    component_transform := Component_Transform {}
    component_transform.position = grid_to_world_position_center(grid_position, GRID_SIZE)
    component_transform.scale = scale
    _game.entities.components_transform[entity] = component_transform
}

entity_add_sprite :: proc(entity: Entity, texture_asset: engine.Asset_Id, texture_position: Vector2i32 = { 0, 0 }, texture_size: Vector2i32 = GRID_SIZE_V2, texture_padding: i32 = 0, z_index: i32 = 0, color: Color = { 1, 1, 1, 1 }) {
    component_rendering := Component_Rendering {}
    component_rendering.visible = true
    component_rendering.texture_asset = texture_asset
    component_rendering.texture_position = texture_position
    component_rendering.texture_size = texture_size
    component_rendering.texture_padding = texture_padding
    component_rendering.z_index = z_index
    component_rendering.color = color
    _game.entities.components_rendering[entity] = component_rendering
}

entity_has_flag :: proc(entity: Entity, flag: Component_Flags_Enum) -> bool {
    component_flag, has_flag := _game.entities.components_flag[entity]
    return has_flag && flag in component_flag.value
}

entity_create_unit :: proc(unit: ^Unit) -> Entity {
    SPRITE_SIZE :: Vector2i32 { 8, 8 }

    entity := entity_make(unit.name)

    hand_left  := entity_make(fmt.tprintf("%s: Hand (left)", unit.name))
    entity_add_transform(hand_left, { 0, 0 })
    (&_game.entities.components_transform[hand_left]).parent = entity
    entity_add_sprite(hand_left, 3, { 5, 15 } * GRID_SIZE_V2, SPRITE_SIZE, 1, 1)
    _game.entities.components_animation[hand_left] = Component_Animation {}

    hand_right := entity_make(fmt.tprintf("%s: Hand (right)", unit.name))
    entity_add_transform(hand_right, { 0, 0 })
    (&_game.entities.components_transform[hand_right]).parent = entity
    entity_add_sprite(hand_right, 3, { 6, 15 } * GRID_SIZE_V2, SPRITE_SIZE, 1, 1)
    _game.entities.components_animation[hand_right] = Component_Animation {}

    entity_add_transform_grid(entity, unit.grid_position)
    entity_add_sprite(entity, 3, unit.sprite_position * GRID_SIZE_V2, SPRITE_SIZE, 1, 1)
    _game.entities.components_flag[entity] = { { .Unit } }
    _game.entities.components_animation[entity] = Component_Animation {}
    _game.entities.components_limbs[entity] = { hand_left = hand_left, hand_right = hand_right }

    return entity
}

entity_move_grid :: proc(entity: Entity, grid_position: Vector2i32) {
    component_transform := &_game.entities.components_transform[entity]
    component_transform.position = grid_to_world_position_center(grid_position, GRID_SIZE)
}

unit_move :: proc(unit: ^Unit, grid_position: Vector2i32) {
    component_transform := &_game.entities.components_transform[unit.entity]
    component_transform.position = grid_to_world_position_center(grid_position, GRID_SIZE)
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

// We don't want to use string literals since they are built into the binary and we want to avoid this when using code reload
// TODO: cache and reuse strings
static_string :: proc(str: string, allocator := context.allocator) -> string {
    return strings.clone(str, allocator)
}

temp_cstring :: proc(str: string) -> cstring {
    return strings.clone_to_cstring(str, context.temp_allocator)
}

entity_to_color :: proc(entity: Entity) -> Color {
    assert(entity <= 0xffffff)

    // FIXME: the "* 48" is here for visual debugging, this will break color to entity
    return Color {
        f32(((entity * 48 / 255 / 255) & 0x00ff0000) >> 16),
        f32(((entity * 48 / 255 / 255) & 0x0000ff00) >> 8),
        f32(((entity * 48 / 255 / 255) & 0x000000ff)),
        1,
    }
}

color_to_entity :: proc(color: Color) -> Entity {
    return transmute(Entity) [4]u8 { u8(color.b) * 48 * 255, u8(color.g) * 48 * 255, u8(color.r) * 48 * 255, 0 }
}

@(test)
entity_to_color_encoding_decoding :: proc(t: ^testing.T) {
    testing.expect(t, entity_to_color(0x000000) == Color { 0,   0,   0,   255 })
    testing.expect(t, entity_to_color(0x0000ff) == Color { 0,   0,   255, 255 })
    testing.expect(t, entity_to_color(0x00ffff) == Color { 0,   255, 255, 255 })
    testing.expect(t, entity_to_color(0xffffff) == Color { 255, 255, 255, 255 })
    testing.expect(t, entity_to_color(0xffff00) == Color { 255, 255, 0,   255 })
    testing.expect(t, entity_to_color(0xff0000) == Color { 255, 0,   0,   255 })
    testing.expect(t, color_to_entity(Color { 0,   0,   0,   0   }) == 0x000000)
    testing.expect(t, color_to_entity(Color { 0,   0,   0,   255 }) == 0x000000)
    testing.expect(t, color_to_entity(Color { 0,   0,   255, 255 }) == 0x0000ff)
    testing.expect(t, color_to_entity(Color { 0,   255, 255, 255 }) == 0x00ffff)
    testing.expect(t, color_to_entity(Color { 255, 255, 255, 255 }) == 0xffffff)
    testing.expect(t, color_to_entity(Color { 255, 255, 0,   255 }) == 0xffff00)
    testing.expect(t, color_to_entity(Color { 255, 0,   0,   255 }) == 0xff0000)
}
