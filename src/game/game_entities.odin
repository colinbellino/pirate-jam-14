package game

import "core:fmt"
import "core:log"
import "core:mem"
import "core:math"
import "core:strings"
import "core:encoding/json"

import "../engine"

Meta_Value :: json.Value;

Entity_Data :: struct {
    entities:                   [dynamic]Entity,
    // Notes: remember to add to entity_delete()
    components_name:            map[Entity]Component_Name,
    components_transform:       map[Entity]Component_Transform,
    components_rendering:       map[Entity]Component_Rendering,
    components_animation:       map[Entity]Component_Animation,
    components_flag:            map[Entity]Component_Flag,
    components_battle_info:     map[Entity]Component_Battle_Info,
    components_z_index:         map[Entity]Component_Z_Index,
    components_collision:       map[Entity]Component_Collision,
    components_meta:            map[Entity]Component_Meta,
}

Entity :: distinct u32;

Component_Map :: map[Entity]Component;

Component :: struct { }

Component_Name :: struct {
    name:               string,
}

Component_Transform :: struct {
    grid_position:      Vector2i,
    world_position:     Vector2f32,
    move_in_progress:   bool,
    move_origin:        Vector2f32,
    move_destination:   Vector2f32,
    move_t:             f32,
    move_speed:         f32,
    size:               Vector2f32,
}

Component_Battle_Info :: struct {
    charge_time:        i32,
    charge_speed:       i32,
}

Component_Rendering :: struct {
    visible:            bool,
    texture_asset:      engine.Asset_Id,
    texture_position:   Vector2i,
    texture_size:       Vector2i,
    flip:               engine.RendererFlip,
}
Component_Z_Index :: struct {
    z_index:            i32,
}

Component_Tile :: struct {
    tile_id:            engine.LDTK_Tile_Id,
}

Component_Animation :: struct {
    t:                  f32,
    speed:              f32,
    direction:          i8,
    revert:             bool,
    current_frame:      int,
    frames:             [dynamic]Vector2i,
}

Component_Flag :: struct {
    value: Component_Flags,
}
Component_Flags :: bit_set[Component_Flags_Enum];
Component_Flags_Enum :: enum i32 {
    None,
    Interactive,
    Tile,
    Unit, // Remove this if we add Component_Unit (more Ally/Foe into it)
    Ally,
    Foe,
}

Component_Collision :: struct {
    rect:               engine.RectF32,
}

Component_Meta :: struct {
    value:              map[string]Meta_Value,
}

entity_delete :: proc(entity: Entity, entity_data: ^Entity_Data) {
    entity_index := -1;
    for e, i in entity_data.entities {
        if e == entity {
            entity_index = i;
            break;
        }
    }
    if entity_index == -1 {
        log.errorf("Entity not found: %v", entity);
        return;
    }

    // TODO: don't delete, disable & flag for reuse
    unordered_remove(&entity_data.entities, entity_index);

    delete_key(&entity_data.components_name, entity);
    delete_key(&entity_data.components_transform, entity);
    delete_key(&entity_data.components_rendering, entity);
    delete_key(&entity_data.components_animation, entity);
    delete_key(&entity_data.components_flag, entity);
    delete_key(&entity_data.components_battle_info, entity);
    delete_key(&entity_data.components_z_index, entity);
    delete_key(&entity_data.components_collision, entity);
    delete_key(&entity_data.components_meta, entity);
}

entity_format :: proc(entity: Entity, entity_data: ^Entity_Data) -> string {
    name := entity_data.components_name[entity].name;
    return fmt.tprintf("%v (%v)", entity, name);
}

entity_make :: proc(name: string, allocator := context.allocator) -> Entity {
    entity := Entity(len(game.entities.entities) + 1);
    append(&game.entities.entities, entity);
    game.entities.components_name[entity] = Component_Name { static_string(name, allocator) };
    // log.debugf("Entity created: %v", game.entities.components_name[entity].name);
    return entity;
}

entity_set_visibility :: proc(entity: Entity, value: bool, entity_data: ^Entity_Data) {
    (&entity_data.components_rendering[entity]).visible = value;
}

entity_move_lerp_grid :: proc(position_component: ^Component_Transform, destination: Vector2i, speed: f32 = 3.0) {
    position_component.move_origin = position_component.world_position;
    position_component.move_destination = Vector2f32(array_cast(destination, f32));
    position_component.grid_position = destination;
    position_component.move_in_progress = true;
    position_component.move_t = 0;
    position_component.move_speed = speed;
}

entity_move_lerp_world :: proc(position_component: ^Component_Transform, destination: Vector2f32, speed: f32 = 1.0) {
    position_component.move_origin = position_component.world_position;
    position_component.move_destination = destination;
    position_component.move_in_progress = true;
    position_component.move_t = 0;
    position_component.move_speed = speed;
}

entity_move_world :: proc(position_component: ^Component_Transform, destination: Vector2f32) {
    position_component.move_origin = position_component.world_position;
    position_component.grid_position = { i32(math.round(position_component.world_position.x)), i32(math.round(position_component.world_position.y)) };
    position_component.world_position = destination;
    position_component.move_in_progress = false;
    position_component.move_t = 0;
    position_component.move_speed = 0;
}

entity_move_grid :: proc(entity: Entity, destination: Vector2i, entity_data: ^Entity_Data) {
    position_component := &(entity_data.components_transform[entity]);
    position_component.grid_position = destination;
    position_component.world_position = Vector2f32(array_cast(destination, f32));
    position_component.move_in_progress = false;
}

entity_get_first_at_position :: proc(grid_position: Vector2i, flag: Component_Flags_Enum, entity_data: ^Entity_Data) -> (found_entity: Entity, found: bool) {
    for entity, component_position in entity_data.components_transform {
        component_flag, has_flag := entity_data.components_flag[entity];
        if component_position.grid_position == grid_position && has_flag && flag in component_flag.value {
            found_entity = entity;
            found = true;
            return;
        }
    }

    return;
}

entity_add_transform :: proc(entity: Entity, grid_position: Vector2i, size: Vector2f32) {
    component_position := Component_Transform {};
    component_position.grid_position = grid_position;
    component_position.world_position = Vector2f32(array_cast(grid_position, f32));;
    component_position.size = size;
    game.entities.components_transform[entity] = component_position;
}

entity_add_sprite :: proc(entity: Entity, texture_asset: engine.Asset_Id, texture_position: Vector2i, texture_size: Vector2i, flip: i32 = 0) {
    component_rendering := Component_Rendering {};
    component_rendering.visible = true;
    component_rendering.texture_asset = texture_asset;
    component_rendering.texture_position = texture_position;
    component_rendering.texture_size = texture_size;
    component_rendering.flip = transmute(engine.RendererFlip) flip;
    game.entities.components_rendering[entity] = component_rendering;
}

// We don't want to use string literals since they are built into the binary and we want to avoid this when using code reload
// TODO: cache and reuse strings
static_string :: proc(str: string, allocator := context.allocator) -> string {
    return strings.clone(str, allocator);
}
