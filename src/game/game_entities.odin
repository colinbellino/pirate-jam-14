package game

import "core:fmt"
import "core:log"
import "core:mem"

import "../engine"

// TODO: Do some assertions to make sure this is always up-to-date
ENTITY_COMPONENT_COUNT :: 9;

Entity_Data :: struct {
    entities:                   [dynamic]Entity,
    components_name:            map[Entity]Component_Name,
    components_position:        map[Entity]Component_Position,
    components_rendering:       map[Entity]Component_Rendering,
    components_animation:       map[Entity]Component_Animation,
    components_world_info:      map[Entity]Component_World_Info,
    components_flag:            map[Entity]Component_Flag,
    components_door:            map[Entity]Component_Door,
    components_battle_info:     map[Entity]Component_Battle_Info,
    components_z_index:         map[Entity]Component_Z_Index,
}

Entity :: distinct i32;

Component_Map :: map[Entity]Component;

Component :: struct { }

Component_Name :: struct {
    name:               string,
}

Component_Position :: struct {
    grid_position:      Vector2i,
    world_position:     Vector2f32,
    move_in_progress:   bool,
    move_origin:        Vector2f32,
    move_destination:   Vector2f32,
    move_t:             f32,
    move_speed:         f32,
}

Component_World_Info :: struct {
    room_index:         i32,
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
}
Component_Z_Index :: struct {
    z_index:            i32,
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

Component_Door :: struct {
    direction:         Vector2i,
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

    for i := 0; i < ENTITY_COMPONENT_COUNT; i += 1 {
        delete_key(mem.ptr_offset(&entity_data.components_name, i * size_of(Component_Map)), entity);
    }
}

entity_format :: proc(entity: Entity, entity_data: ^Entity_Data) -> string {
    name := entity_data.components_name[entity].name;
    return fmt.tprintf("%v (%v)", entity, name);
}

entity_make :: proc(name: string, entity_data: ^Entity_Data) -> Entity {
    entity := Entity(len(entity_data.entities) + 1);
    append(&entity_data.entities, entity);
    entity_data.components_name[entity] = Component_Name { static_string(name) };
    // log.debugf("Entity created: %v", entity_format(game, entity));
    return entity;
}

entity_set_visibility :: proc(entity: Entity, value: bool, entity_data: ^Entity_Data) {
    (&entity_data.components_rendering[entity]).visible = value;
}

entity_make_component_position :: proc(grid_position: Vector2i) -> Component_Position {
    world_position := Vector2f32(array_cast(grid_position, f32));
    component_position := Component_Position {};
    component_position.grid_position = grid_position;
    component_position.world_position = world_position;
    return component_position;
}

entity_move_lerp_grid :: proc(position_component: ^Component_Position, destination: Vector2i, speed: f32 = 3.0) {
    position_component.move_origin = position_component.world_position;
    position_component.move_destination = Vector2f32(array_cast(destination, f32));
    position_component.grid_position = destination;
    position_component.move_in_progress = true;
    position_component.move_t = 0;
    position_component.move_speed = speed;
}

entity_move_lerp_world :: proc(position_component: ^Component_Position, destination: Vector2f32, speed: f32 = 1.0) {
    position_component.move_origin = position_component.world_position;
    position_component.move_destination = destination;
    position_component.move_in_progress = true;
    position_component.move_t = 0;
    position_component.move_speed = speed;
}

entity_move_world :: proc(position_component: ^Component_Position, destination: Vector2f32) {
    position_component.move_origin = position_component.world_position;
    position_component.world_position = destination;
    position_component.move_in_progress = false;
    position_component.move_t = 0;
    position_component.move_speed = 0;
}

entity_move_grid :: proc(entity: Entity, destination: Vector2i, entity_data: ^Entity_Data) {
    position_component := &(entity_data.components_position[entity]);
    position_component.grid_position = destination;
    position_component.world_position = Vector2f32(array_cast(destination, f32));
    position_component.move_in_progress = false;
}

entity_get_first_at_position :: proc(grid_position: Vector2i, flag: Component_Flags_Enum, entity_data: ^Entity_Data) -> (found_entity: Entity, found: bool) {
    for entity, component_position in entity_data.components_position {
        component_flag, has_flag := entity_data.components_flag[entity];
        if component_position.grid_position == grid_position && has_flag && flag in component_flag.value {
            found_entity = entity;
            found = true;
            return;
        }
    }

    return;
}
