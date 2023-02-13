package game

import "core:fmt"
import "core:log"

Entity :: distinct i32;

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

Component_Rendering :: struct {
    visible:            bool,
    z_index:            i32,
    texture_index:      int,
    texture_position:   Vector2i,
    texture_size:       Vector2i,
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
    Unit,
    Ally,
    Foe,
}

Component_Door :: struct {
    direction:         Vector2i,
}

entity_delete :: proc(entity: Entity, game_state: ^Game_State) {
    entity_index := -1;
    for e, i in game_state.entities {
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
    unordered_remove(&game_state.entities, entity_index);
    delete_key(&game_state.components_name, entity);
    delete_key(&game_state.components_position, entity);
    delete_key(&game_state.components_rendering, entity);
    delete_key(&game_state.components_animation, entity);
    delete_key(&game_state.components_world_info, entity);
    delete_key(&game_state.components_flag, entity);
    delete_key(&game_state.components_door, entity);
}

entity_format :: proc(entity: Entity, game_state: ^Game_State) -> string {
    name := game_state.components_name[entity].name;
    return fmt.tprintf("%v (%v)", entity, name);
}

entity_make :: proc(name: string, game_state: ^Game_State) -> Entity {
    entity := Entity(len(game_state.entities) + 1);
    append(&game_state.entities, entity);
    game_state.components_name[entity] = Component_Name { name };
    // log.debugf("Entity created: %v", entity_format(game_state, entity));
    return entity;
}

entity_set_visibility :: proc(entity: Entity, value: bool, game_state: ^Game_State) {
    (&game_state.components_rendering[entity]).visible = value;
}

entity_make_component_position :: proc(grid_position: Vector2i) -> Component_Position {
    world_position := Vector2f32(array_cast(grid_position, f32));
    component_position := Component_Position {};
    component_position.grid_position = grid_position;
    component_position.world_position = world_position;
    return component_position;
}

entity_move_grid :: proc(position_component: ^Component_Position, destination: Vector2i, speed: f32 = 3.0) {
    position_component.move_origin = position_component.world_position;
    position_component.move_destination = Vector2f32(array_cast(destination, f32));
    position_component.grid_position = destination;
    position_component.move_in_progress = true;
    position_component.move_t = 0;
    position_component.move_speed = speed;
}

entity_move_world :: proc(position_component: ^Component_Position, destination: Vector2f32, speed: f32 = 3.0) {
    position_component.move_origin = position_component.world_position;
    position_component.move_destination = destination;
    position_component.move_in_progress = true;
    position_component.move_t = 0;
    position_component.move_speed = speed;
}

entity_move_instant :: proc(entity: Entity, destination: Vector2i, game_state: ^Game_State) {
    position_component := &(game_state.components_position[entity]);
    position_component.grid_position = destination;
    position_component.world_position = Vector2f32(array_cast(destination, f32));
    position_component.move_in_progress = false;
}

entity_get_first_at_position :: proc(grid_position: Vector2i, flag: Component_Flags_Enum, game_state: ^Game_State) -> (found_entity: Entity, found: bool) {
    for entity, component_position in game_state.components_position {
        component_flag, has_flag := game_state.components_flag[entity];
        if component_position.grid_position == grid_position && has_flag && flag in component_flag.value {
            found_entity = entity;
            found = true;
            return;
        }
    }

    return;
}
