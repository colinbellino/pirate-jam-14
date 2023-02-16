package game

import "core:log"
import "core:fmt"

import platform "../engine/platform"
import ui "../engine/renderer/ui"

World_Mode_Battle :: struct {
    battle_mode:                Battle_Mode,
    battle_mode_initialized:    bool,

    entities:                   [dynamic]Entity,
    turn_actor:                 Entity,
}

battle_mode_update :: proc(game_state: ^Game_State, platform_state: ^platform.Platform_State, world_data: ^Game_Mode_World) {
    battle_data := cast(^World_Mode_Battle) world_data.world_mode_data;

    if ui_window("Units", { 200, 0, 200, 500 }) {
        ui_layout_row({ -1 }, 0);
        for entity in battle_data.entities {
            if entity == battle_data.turn_actor {
                ui_label(fmt.tprintf("%v *", entity_format(entity, &game_state.entities)));
            } else {
                ui_label(entity_format(entity, &game_state.entities));
            }
        }
    }

    switch battle_data.battle_mode {
        case .None: {
            for entity, world_info in game_state.entities.components_world_info {
                component_flag, has_flag := game_state.entities.components_flag[entity];
                if world_info.room_index == game_state.current_room_index && (has_flag && .Unit in component_flag.value) {
                    append(&battle_data.entities, entity);
                    game_state.entities.components_battle_info[entity] = Component_Battle_Info { 0 };
                }
            }

            log.debugf("start battle: %v", battle_data.entities);
            set_battle_mode(battle_data, .Wait_For_Charge);
        }

        case .Wait_For_Charge: {
            battle_data.turn_actor = 0;

            for entity in battle_data.entities {
                component_battle_info := &game_state.entities.components_battle_info[entity];
                component_battle_info.charge_time += 1;

                if component_battle_info.charge_time >= 100 {
                    battle_data.turn_actor = entity;
                    set_battle_mode(battle_data, .Start_Turn);
                    break;
                }
            }
        }

        case .Start_Turn: {
            entity := battle_data.turn_actor;

            if battle_data.battle_mode_initialized == false {
                log.debugf("Start_Turn: %v", entity_format(entity, &game_state.entities));
                battle_data.battle_mode_initialized = true;
            }

            if platform_state.keys[.SPACE].released {
                component_battle_info := &game_state.entities.components_battle_info[entity];
                component_battle_info.charge_time = 0;
                set_battle_mode(battle_data, .Wait_For_Charge);
            }
        }

        case .Ended: {
            log.debug("Ended");
        }
    }
}
