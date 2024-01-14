package game

import "core:encoding/json"
import "core:fmt"
import "core:log"
import "core:math/rand"
import "core:math/linalg"
import "core:mem"
import "core:os"
import "core:slice"
import "core:sort"
import "core:strings"
import "core:time"
import "../engine"

Play_State :: struct {
    entered_at:             time.Time,
    entities:               [dynamic]Entity,
    player:                 Entity,
    adventurer:             Entity,
    levels:                 []^Level,
    current_level_index:    int,
    waypoints:              []Vector2f32,
    waypoints_current:      int,
    room_transition:        ^engine.Animation,
}

game_mode_play :: proc() {
    frame_stat := engine.get_frame_stat()
    time_scale := engine.get_time_scale()
    camera := &_mem.game.world_camera

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

        tile_meta_components, entity_indices, tile_meta_components_err := engine.entity_get_components(engine.Component_Tile_Meta)
        assert(tile_meta_components_err == .None)

        adv_spawn_position := Vector2f32 { 0, 0 }
        adv_count := 0
        player_spawn_position := Vector2f32 { 0, 0 }
        player_count := 0
        for entity, i in entity_indices {
            if tile_meta_components[i].entity_uid == LDTK_ENTITY_ID_ADVENTURER_SPAWN {
                component_transform := engine.entity_get_component(entity, engine.Component_Transform)
                adv_spawn_position = component_transform.position
                adv_count += 1
            }
            if tile_meta_components[i].entity_uid == LDTK_ENTITY_ID_PLAYER_SPAWN {
                component_transform := engine.entity_get_component(entity, engine.Component_Transform)
                player_spawn_position = component_transform.position
                player_count += 1
            }
        }
        assert(adv_count == 1, fmt.tprintf("Only 1 adv per level, received %v.", adv_count))
        assert(player_count == 1, fmt.tprintf("Only 1 player per level, received %v.", player_count))

        { entity := engine.entity_create_entity("Ján Ïtor")
            component_transform, component_transform_err := engine.entity_set_component(entity, engine.Component_Transform {
                position = player_spawn_position,
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

            append(&_mem.game.play.entities, entity)
            _mem.game.play.player = entity
        }

        { entity := engine.entity_create_entity("Ad Venturer")
            component_transform, component_transform_err := engine.entity_set_component(entity, engine.Component_Transform {
                position = adv_spawn_position,
                scale = { 2, 2 },
            })
            component_sprite, component_sprite_err := engine.entity_set_component(entity, engine.Component_Sprite {
                texture_asset = _mem.game.asset_image_spritesheet,
                texture_size = { 32, 32 },
                texture_position = grid_position(6, 6),
                texture_padding = TEXTURE_PADDING,
                tint = { 1, 0.5, 0.5, 1 },
                shader_asset = _mem.game.asset_shader_sprite,
            })
            append(&_mem.game.play.entities, entity)
            _mem.game.play.adventurer = entity
        }

        reset_draw_line()
        {
            path_components, entity_indices, path_components_err := engine.entity_get_components(Component_Path)
            assert(path_components_err == .None)

            points := make([dynamic]Vector2f32, context.temp_allocator)

            done := make([]Entity, len(entity_indices), context.temp_allocator)
            entities, entities_err := slice.map_keys(entity_indices, context.temp_allocator)
            entity := entities[0]
            i := 0
            for true {
                path_component := path_components[entity_indices[entity]]
                current_transform := engine.entity_get_component(entity, engine.Component_Transform)
                previous_transform := engine.entity_get_component(path_component.previous, engine.Component_Transform)
                // append(&points, previous_transform.position)
                append(&points, current_transform.position)

                if slice.contains(done, path_component.previous) {
                    break
                }
                entity = path_component.previous
                done[i] = path_component.previous
                i += 1
            }
            append_line_points(points[:], { 0, 1, 0, 1 })

            _mem.game.play.waypoints = slice.clone(points[:])
            _mem.game.play.waypoints_current = 0

            component_transform := engine.entity_get_component(_mem.game.play.adventurer, engine.Component_Transform)
            adv_position := component_transform.position

            for point, i in _mem.game.play.waypoints {
                dist1 := linalg.length(adv_position - point)
                dist2 := linalg.length(adv_position - _mem.game.play.waypoints[_mem.game.play.waypoints_current])
                if dist1 < dist2 {
                    _mem.game.play.waypoints_current = i
                }
            }
        }
    }

    if game_mode_running() {
        {
            direction := Vector2f32 {}
            if engine.ui_button("left") {
                direction = Vector2f32 { -1, 0 }
            }
            engine.ui_same_line()
            if engine.ui_button("right") {
                direction = Vector2f32 { 1, 0 }
            }

            if engine.ui_button("up") {
                direction = Vector2f32 { 0, -1 }
            }
            engine.ui_same_line()
            if engine.ui_button("down") {
                direction = Vector2f32 { 0, 1 }
            }

            if direction != {} {
                make_room_transition(direction)
            }
        }

        if _mem.game.player_inputs.modifier == {} {
            player_move := Vector2f32 {}
            if _mem.game.player_inputs.aim != {} {
                player_move = _mem.game.player_inputs.aim
            }

            if player_move != {} {
                component_transform := engine.entity_get_component(_mem.game.play.player, engine.Component_Transform)
                component_transform.position = component_transform.position + (player_move * frame_stat.delta_time * time_scale) / 5
            }
        }

        adventurer_movement: {
            component_transform := engine.entity_get_component(_mem.game.play.adventurer, engine.Component_Transform)

            current_destination := _mem.game.play.waypoints[_mem.game.play.waypoints_current]
            diff := current_destination - component_transform.position
            if abs(diff.x) + abs(diff.y) < 1 {
                _mem.game.play.waypoints_current = (_mem.game.play.waypoints_current + 1) % len(_mem.game.play.waypoints)
                // log.debugf("break adventurer_movement")
                break adventurer_movement
            }

            direction := linalg.normalize(diff)
            if direction != {} {
                component_transform.position = component_transform.position + (direction * frame_stat.delta_time * time_scale) / 15
            }
        }

        update_draw_line()
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

make_room_transition :: proc(direction: Vector2f32) {
    context.allocator = _mem.game.arena.allocator

    origin := _mem.game.world_camera.position
    room_size := engine.vector_i32_to_f32(_mem.game.play.levels[_mem.game.play.current_level_index].size / 2 * GRID_SIZE)
    destination := origin + (direction * room_size)

    animation := engine.animation_create_animation(1)
    animation.loop = false
    animation.active = true
    engine.animation_add_curve(animation, engine.Animation_Curve_Position {
        target = &_mem.game.world_camera.position,
        timestamps = { 0.0, 1.0 },
        frames = { origin, destination },
    })

    _mem.game.play.room_transition = animation
}
