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
        for entity in battle_data.entities {
            ui_layout_row({ -1 }, 20);
            component_battle_info := &game_state.entities.components_battle_info[entity];

            if entity == battle_data.turn_actor {
                ui_label(fmt.tprintf("%v *", entity_format(entity, &game_state.entities)));
            } else {
                ui_label(entity_format(entity, &game_state.entities));
            }

            layout := ui_get_layout();
            bla := ui_layout_next();
            ui_draw_rect({ bla.x + 0, bla.y + 0, component_battle_info.charge_time, 5 }, { 255, 255, 0, 255 });
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

            if ui_window(fmt.tprintf("Turn: %v", entity_format(entity, &game_state.entities)), { 300, 300, 200, 200 }) {
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
