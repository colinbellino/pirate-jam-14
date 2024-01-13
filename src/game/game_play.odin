package game

import "core:encoding/json"
import "core:fmt"
import "core:log"
import "core:math/rand"
import "core:mem"
import "core:os"
import "core:slice"
import "core:sort"
import "core:strings"
import "core:time"
import "../engine"

Play_State :: struct {
    entered_at:          time.Time,
    entities:            [dynamic]Entity,
    player:              Entity,
    levels:              []^Level,
    current_level_index: int,
}

game_mode_play :: proc() {
    frame_stat := engine.get_frame_stat()

    if game_mode_entering() {
        _mem.game.play.entered_at = time.now()
        log.debugf("[PLAY] entered at %v", _mem.game.play.entered_at)

        _mem.game.render_command_clear.pass_action.colors[0].clear_value = { 0.1, 0.1, 0.1, 1 }

        asset_info, asset_info_ok := engine.asset_get_asset_info_map(_mem.game.asset_map_rooms)
        assert(asset_info_ok, "asset not loaded")

        level_ids := []string {
            "Room_0",
            "Room_1",
            "Room_2",
            "Room_3",
            "Room_4",
        }
        _mem.game.play.levels = make_levels(asset_info, level_ids, TEXTURE_PADDING, _mem.game.arena.allocator)

        _mem.game.world_camera.zoom = CAMERA_ZOOM_INITIAL
        _mem.game.world_camera.position.xy = auto_cast(engine.vector_i32_to_f32(_mem.game.play.levels[_mem.game.play.current_level_index].size * GRID_SIZE) / 4)

        { entity := engine.entity_create_entity("Counter")
            component_transform, component_transform_err := engine.entity_set_component(entity, engine.Component_Transform {
                position = grid_to_world_position_center({ 0, 0 }),
                scale = { 1, 1 },
            })
            component_sprite, component_sprite_err := engine.entity_set_component(entity, engine.Component_Sprite {
                texture_asset = _mem.game.asset_image_test,
                texture_size = { 32, 32 },
                texture_position = { 0, 0 },
                texture_padding = 0,
                tint = { 1, 1, 1, 1 },
                shader_asset = _mem.game.asset_shader_sprite,
            })

            {
                ase_animation := new(Aseprite_Animation)
                data, read_ok := os.read_entire_file("media/art/test.json")
                error := json.unmarshal(data, ase_animation, json.DEFAULT_SPECIFICATION)
                assert(error == nil)
                // log.debugf("error: %v %v", error, ase_animation)

                animation := make_aseprite_animation(ase_animation, &component_sprite.texture_position)
            }

            append(&_mem.game.play.entities, entity)
        }

        { entity := engine.entity_create_entity("Ján Ïtor")
            component_transform, component_transform_err := engine.entity_set_component(entity, engine.Component_Transform {
                position = grid_to_world_position_center(_mem.game.play.levels[_mem.game.play.current_level_index].size / 2),
                scale = { 2, 2 },
            })
            component_sprite, component_sprite_err := engine.entity_set_component(entity, engine.Component_Sprite {
                texture_asset = _mem.game.asset_image_spritesheet,
                texture_size = { 32, 32 },
                texture_position = grid_position(6, 6),
                texture_padding = TEXTURE_PADDING,
                tint = { 1, 1, 1, 1 },
                shader_asset = _mem.game.asset_shader_sprite,
            })

            // {
            //     ase_animation := new(Aseprite_Animation)
            //     data, read_ok := os.read_entire_file("media/art/test.json")
            //     error := json.unmarshal(data, ase_animation, json.DEFAULT_SPECIFICATION)
            //     assert(error == nil)
            //     // log.debugf("error: %v %v", error, ase_animation)

            //     animation := make_aseprite_animation(ase_animation, &component_sprite.texture_position)
            // }

            append(&_mem.game.play.entities, entity)
            _mem.game.play.player = entity
        }
    }

    if game_mode_running() {
        {
            player_move := Vector2f32 {}
            if _mem.game.player_inputs.aim != {} {
                player_move = _mem.game.player_inputs.aim
            }

            if player_move != {} {
                component_transform, component_transform_err := engine.entity_get_component(_mem.game.play.player, engine.Component_Transform)
                assert(component_transform_err == .None)

                component_transform.position = component_transform.position + (player_move * frame_stat.delta_time) / 5
            }
        }
    }

    if game_mode_exiting() {
        log.debug("[PLAY] exit")
        for level in _mem.game.play.levels {
            for entity in level.entities {
                // log.debugf("deleting entity: %v", entity)
                engine.entity_delete_entity(entity)
            }
        }
        for entity in _mem.game.play.entities {
            // log.debugf("deleting entity: %v", entity)
            engine.entity_delete_entity(entity)
        }
        clear(&_mem.game.play.entities)
    }
}
