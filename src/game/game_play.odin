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
    entered_at:     time.Time,
    entities:       [dynamic]Entity,
}

game_mode_play :: proc() {
    @(static) state: Play_State

    if game_mode_entering() {
        state.entered_at = time.now()
        log.debugf("[PLAY] entered at %v", state.entered_at)

        _mem.game.render_command_clear.pass_action.colors[0].clear_value = { 0.1, 0.1, 0.1, 1 }

        asset_info, asset_info_ok := engine.asset_get_asset_info_map(_mem.game.asset_map_rooms)
        assert(asset_info_ok, "asset not loaded")
        _mem.game.level = make_level(asset_info, "Room_0", TEXTURE_PADDING, _mem.game.arena.allocator)
        // log.debugf("_mem.game.level: %v", _mem.game.level)

        _mem.game.world_camera.zoom = CAMERA_ZOOM_INITIAL
        _mem.game.world_camera.position.xy = auto_cast(engine.vector_i32_to_f32(_mem.game.level.size * GRID_SIZE) / 4)

        {
            entity := engine.entity_create_entity("Hello")
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

            append(&state.entities, entity)
        }
    }

    if game_mode_running() {
        engine.ui_text("level_size: %v", _mem.game.level.size)
        engine.ui_text("level_size: %v", _mem.game.level.size * GRID_SIZE)
    }

    if game_mode_exiting() {
        log.debug("[PLAY] exit")
        log.debugf("_mem.game.level.entities: %v", _mem.game.level.entities)
        for entity in _mem.game.level.entities {
            // log.debugf("deleting entity: %v", entity)
            engine.entity_delete_entity(entity)
        }
        for entity in state.entities {
            // log.debugf("deleting entity: %v", entity)
            engine.entity_delete_entity(entity)
        }
        clear(&state.entities)
    }
}
