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

    if ui_window("Units", { 900, 0, 200, 300 }, { .NO_CLOSE, .NO_RESIZE }) {
        for entity in battle_data.entities {
            ui_layout_row({ -1 }, 0);
            component_battle_info := &game_state.entities.components_battle_info[entity];

            if entity == battle_data.turn_actor {
                ui_label(fmt.tprintf("%v *", entity_format(entity, &game_state.entities)));
            } else {
                ui_label(entity_format(entity, &game_state.entities));
            }

            charge_progress := f32(component_battle_info.charge_time) / 100.0;
            ui_progress_bar(charge_progress, 5);
        }
    }

    switch battle_data.battle_mode {
        case .None: {
            for entity, world_info in game_state.entities.components_world_info {
                component_flag, has_flag := game_state.entities.components_flag[entity];
                if world_info.room_index == game_state.current_room_index && (has_flag && .Unit in component_flag.value) {
                    append(&battle_data.entities, entity);
                    speed : i32 = 2;
                    if entity % 2 == 0 {
                        speed = 3;
                    }
                    game_state.entities.components_battle_info[entity] = Component_Battle_Info { 0, speed };
                }
            }

            set_battle_mode(battle_data, .Wait_For_Charge);
        }

        case .Wait_For_Charge: {
            battle_data.turn_actor = 0;

            for entity in battle_data.entities {
                component_battle_info := &game_state.entities.components_battle_info[entity];
                component_battle_info.charge_time += component_battle_info.charge_speed;

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
                battle_data.battle_mode_initialized = true;
            }

            action_selected := false;

            label := fmt.tprintf("Turn: %v", entity_format(entity, &game_state.entities));
            if ui_window(label, { 500, 500, 200, 200 }, { .NO_CLOSE, .NO_RESIZE }) {
                ui_layout_row({ -1 }, 0);
                actions := []string { "Move", "Act", "Wait" };
                for action in actions {
                    if .SUBMIT in ui_button(action) {
                        log.debugf("action clicked: %v", action);
                        action_selected = true;
                    }
                }
            }

            if platform_state.keys[.SPACE].released {
                action_selected = true;
            }

            if action_selected {
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
