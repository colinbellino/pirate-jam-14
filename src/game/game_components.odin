package game

import "core:time"
import "../engine"

Component_Limbs :: struct {
    hand_left: Entity,
    hand_right: Entity,
}

Component_Flag :: struct {
    value: Component_Flags,
}

Component_Flags :: bit_set[Component_Flags_Enum]
Component_Flags_Enum :: enum i32 {
    None        = 0,
    Interactive = 1 << 0,
    Tile        = 1 << 1,
    Unit        = 1 << 2,
    Ally        = 1 << 3,
    Foe         = 1 << 4,
}

entity_has_flag :: proc(entity: Entity, flag: Component_Flags_Enum) -> bool {
    component_flag, err_flag := engine.entity_get_component_err(entity, Component_Flag)
    return err_flag == .None && flag in component_flag.value
}

Component_Path :: struct {
    previous:   Entity,
}

Component_Collider :: struct {
    type:       Collider_Flags,
    box:        Vector4f32,
    offset:     Vector2f32,
}
Collider_Flags :: bit_set[Collider_Types]
Collider_Types :: enum {
    None        = 0,
    Block       = 1 << 0,
    Interact    = 1 << 1,
    Clean       = 1 << 2,
}

Component_Mess_Creator :: struct {
    on_click:       bool,
    on_death:       bool,
    on_timer:       bool,
    timer_at:       time.Time,
    timer_cooldown: time.Duration,
}

Component_Mess :: struct {
    progress:         f32,
}

Component_Interactive_Primary   :: distinct Component_Interactive
Component_Interactive_Secondary :: distinct Component_Interactive
Component_Interactive :: struct {
    type:                   Interaction_Type,
    progress:               f32,
    done:                   bool,
    cooldown_end:           time.Time,
}
Interaction_Type :: enum {
    Invalid,
    Carry,
    Repair_Torch,
    Refill_Water,
    Pet,
}

// Component_Pet :: struct {
//     can_pet_at:     time.Time,
// }

Component_Dead :: struct {
    animation_t:    f32,
}

Component_Carrier :: struct {
    target:         Entity,
}

Component_Adventurer :: struct {
    mode: Adventurer_Mode,
}
Adventurer_Mode :: enum { Idle, Waypoints, Combat }
