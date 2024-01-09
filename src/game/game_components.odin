package game

import engine "../engine_v2"

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
    component_flag, err_flag := engine.entity_get_component(entity, Component_Flag)
    return err_flag == .None && flag in component_flag.value
}
