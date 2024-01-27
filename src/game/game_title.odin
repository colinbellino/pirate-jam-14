package game

import "core:fmt"
import "core:log"
import "core:math/rand"
import "../engine"

Title_Action :: enum {
    None,
    Start,
    Quit,
 }

game_mode_title :: proc() {
    @(static) entity_title: Entity

    if game_mode_entering() {
        _mem.game.render_command_clear.pass_action.colors[0].clear_value = { 0.945, 0.682, 0.608, 1 }

        { entity := engine.entity_create_entity("Title")
            component_transform, component_transform_err := engine.entity_set_component(entity, engine.Component_Transform {
                position = { 320/2, 180/2 },
                scale = { 20, 11.25 },
            })
            engine.entity_set_component(entity, engine.Component_Sprite {
                texture_asset = _mem.game.asset_image_title,
                texture_size = { 320, 180 },
                texture_position = { 0, 0 },
                texture_padding = TEXTURE_PADDING,
                z_index = i32(len(Level_Layers)) - i32(Level_Layers.Entities),
                tint = { 1, 1, 1, 1 },
                shader_asset = _mem.game.asset_shader_sprite,
            })
            entity_title = entity
        }
        { entity := engine.entity_create_entity("Jan")
            component_transform, component_transform_err := engine.entity_set_component(entity, engine.Component_Transform {
                position = { 260/2, 180-32 },
                scale = { 5, 4 },
            })
            engine.entity_set_component(entity, engine.Component_Sprite {
                texture_asset = _mem.game.asset_image_spritesheet,
                texture_size = { 80, 64 },
                texture_position = { 304, 64 },
                texture_padding = TEXTURE_PADDING,
                z_index = i32(len(Level_Layers)) - i32(Level_Layers.Entities) + 1,
                tint = { 1, 1, 1, 1 },
                shader_asset = _mem.game.asset_shader_sprite,
            })
            entity_title = entity
        }

        // scene_transition_start(.Unswipe_Left_To_Right)
    }

    if game_mode_running() {
        // if scene_transition_is_done() == false {
        //     return
        // }

        action := Title_Action.None
        when TITLE_SKIP { action = .Start }

        if _mem.game.player_inputs.cancel.released {
            action = .Quit
        } else if _mem.game.player_inputs.confirm.released || _mem.game.player_inputs.back.released {
            action = .Start
        }

        switch action {
            case .None: { }
            case .Start: {
                // TODO: screen transition
                save_slot := 0
                load_ok := load_save_slot(save_slot)
                if load_ok {
                    // scene_transition_start(.Swipe_Left_To_Right)
                    game_mode_transition(.Play)
                } else {
                    log.errorf("Couldn't load save_slot: %v", save_slot)
                }
            }
            case .Quit: {
                _mem.game.quit_requested = true
            }
        }
    }

    if game_mode_exiting() {
        log.debugf("Title exit")
        engine.entity_delete_entity(entity_title)
    }
}

load_save_slot :: proc(slot: int) -> (ok: bool) {
    _mem.game.rand = rand.create(12)
    _mem.game.current_level = 0
    return true
}
