package game

import "core:encoding/json"
import "core:fmt"
import "core:log"
import "core:math"
import "core:math/rand"
import "core:math/linalg"
import "core:mem"
import "core:os"
import "core:slice"
import "core:sort"
import "core:strings"
import "core:time"
import "core:testing"
import "../engine"

INTERACT_RANGE              :: f32(32)
PET_COOLDOWN                :: 500 * time.Millisecond
ADVENTURER_MESS_COOLDOWN    :: 3 * time.Second
WATER_LEVEL_MAX             :: 1

Play_State :: struct {
    entered_at:             time.Time,
    entities:               [dynamic]Entity,
    player:                 Entity,
    adventurer:             Entity,
    bucket:                 Entity,
    levels:                 []^Level,
    current_level_index:    int,
    waypoints:              []Vector2f32,
    waypoints_current:      int,
    room_transition:        ^engine.Animation,
    colliders:              [dynamic]Vector4f32,
    recompute_colliders:    bool,
    water_level:            f32,
}

game_mode_play :: proc() {
    frame_stat := engine.get_frame_stat()
    time_scale := engine.get_time_scale()
    window_size := engine.get_window_size()
    camera := &_mem.game.world_camera
    camera_bounds := get_world_camera_bounds()
    mouse_position := engine.mouse_get_position()
    mouse_world_position := window_to_world_position(mouse_position)

    camera_bounds_visible := camera_bounds
    camera_bounds_visible.xy += 0.001
    camera_bounds_visible.zw *= 0.999

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

        current_level := _mem.game.play.levels[_mem.game.play.current_level_index]
        _mem.game.world_camera.zoom = CAMERA_ZOOM_INITIAL
        _mem.game.world_camera.position = engine.vector_i32_to_f32(current_level.position * current_level.size * GRID_SIZE)

        // { entity := engine.entity_create_entity("Counter")
        //     component_transform, component_transform_err := engine.entity_set_component(entity, engine.Component_Transform {
        //         position = grid_to_world_position_center({ 0, 0 }),
        //         scale = { 1, 1 },
        //     })
        //     component_sprite, component_sprite_err := engine.entity_set_component(entity, engine.Component_Sprite {
        //         texture_asset = _mem.game.asset_image_test,
        //         texture_size = { 32, 32 },
        //         texture_position = { 0, 0 },
        //         texture_padding = 0,
        //         tint = { 1, 1, 1, 1 },
        //         shader_asset = _mem.game.asset_shader_sprite,
        //     })

        //     {
        //         ase_animation := new(Aseprite_Animation)
        //         data, read_ok := os.read_entire_file("media/art/test.json")
        //         error := json.unmarshal(data, ase_animation, json.DEFAULT_SPECIFICATION)
        //         assert(error == nil)
        //         // log.debugf("error: %v %v", error, ase_animation)

        //         animation := make_aseprite_animation(ase_animation, &component_sprite.texture_position)
        //     }

        //     append(&_mem.game.play.entities, entity)
        // }

        tile_meta_components, entity_indices, tile_meta_components_err := engine.entity_get_components(engine.Component_Tile_Meta)
        assert(tile_meta_components_err == .None)

        adv_spawn_position := Vector2f32 { 0, 0 }
        adv_count := 0
        player_spawn_position := Vector2f32 { 0, 0 }
        player_count := 0
        bucket_spawn_position := Vector2f32 { 0, 0 }
        bucket_count := 0
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
            if tile_meta_components[i].entity_uid == LDTK_ENTITY_ID_BUCKET_SPAWN {
                component_transform := engine.entity_get_component(entity, engine.Component_Transform)
                bucket_spawn_position = component_transform.position
                bucket_count += 1
            }
        }
        assert(adv_count    == 1, fmt.tprintf("Only 1 adv per level, received %v.", adv_count))
        assert(player_count == 1, fmt.tprintf("Only 1 player per level, received %v.", player_count))
        assert(bucket_count == 1, fmt.tprintf("Only 1 bucket per level, received %v.", bucket_count))

        { entity := engine.entity_create_entity("Ján Ïtor")
            component_transform, component_transform_err := engine.entity_set_component(entity, engine.Component_Transform {
                position = player_spawn_position,
                scale = { 2, 2 },
            })
            component_sprite, component_sprite_err := engine.entity_set_component(entity, engine.Component_Sprite {
                texture_asset = _mem.game.asset_image_spritesheet,
                texture_size = GRID_SIZE_V2 * 2,
                texture_position = grid_position(6, 6),
                texture_padding = TEXTURE_PADDING,
                z_index = i32(len(Level_Layers)) - i32(Level_Layers.Entities),
                tint = { 0, 1, 1, 1 },
                shader_asset = _mem.game.asset_shader_sprite,
            })
            collider_size := GRID_SIZE_V2F32 * 0.5
            engine.entity_set_component(entity, Component_Collider {
                box = { component_transform.position.x - collider_size.x / 2, component_transform.position.y - collider_size.y / 2, collider_size.x, collider_size.y },
            })
            append(&_mem.game.play.entities, entity)
            _mem.game.play.player = entity
        }

        { entity := engine.entity_create_entity("Bucket Kid")
            position := bucket_spawn_position
            component_transform, component_transform_err := engine.entity_set_component(entity, engine.Component_Transform {
                position = position,
                scale = { 2, 2 },
            })
            component_sprite, component_sprite_err := engine.entity_set_component(entity, engine.Component_Sprite {
                texture_asset = _mem.game.asset_image_spritesheet,
                texture_size = GRID_SIZE_V2 * 2,
                texture_position = grid_position(1, 6),
                texture_padding = TEXTURE_PADDING,
                z_index = i32(len(Level_Layers)) - i32(Level_Layers.Entities),
                tint = { 1, 1, 1, 1 },
                shader_asset = _mem.game.asset_shader_sprite,
            })
            collider_size := GRID_SIZE_V2F32 * component_transform.scale
            engine.entity_set_component(entity, Component_Collider {
                box = { position.x - collider_size.x / 2, position.y - collider_size.y / 2, collider_size.x, collider_size.y },
                type = { .Block, .Interact },
            })
            engine.entity_set_component(entity, Component_Refill {})
            append(&_mem.game.play.entities, entity)
            _mem.game.play.bucket = entity
        }

        { entity := engine.entity_create_entity("Ad Venturer")
            component_transform, component_transform_err := engine.entity_set_component(entity, engine.Component_Transform {
                position = adv_spawn_position,
                scale = { 2, 2 },
            })
            component_sprite, component_sprite_err := engine.entity_set_component(entity, engine.Component_Sprite {
                texture_asset = _mem.game.asset_image_spritesheet,
                texture_size = GRID_SIZE_V2 * 2,
                texture_position = grid_position(6, 6),
                texture_padding = TEXTURE_PADDING,
                z_index = i32(len(Level_Layers)) - i32(Level_Layers.Entities),
                tint = { 1, 1, 1, 1 },
                shader_asset = _mem.game.asset_shader_sprite,
            })
            component_mess_creator, component_mess_creator_err := engine.entity_set_component(entity, Component_Mess_Creator {
                on_timer = true,
                timer_cooldown = ADVENTURER_MESS_COOLDOWN,
            })
            append(&_mem.game.play.entities, entity)
            _mem.game.play.adventurer = entity
        }

        // reset_draw_line()
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
        player_transform := engine.entity_get_component(_mem.game.play.player, engine.Component_Transform)
        player_collider := engine.entity_get_component(_mem.game.play.player, Component_Collider)
        current_level := _mem.game.play.levels[_mem.game.play.current_level_index]

        transform_components, transform_entity_indices, collider_components, collider_entity_indices := check_update_components()

        check_update_components :: proc() -> ([]engine.Component_Transform, map[Entity]uint, []Component_Collider, map[Entity]uint) {
            transform_components, transform_entity_indices, transform_components_err := engine.entity_get_components(engine.Component_Transform)
            assert(transform_components_err == .None)
            collider_components, collider_entity_indices, collider_components_err := engine.entity_get_components(Component_Collider)
            assert(collider_components_err == .None)
            return transform_components, transform_entity_indices, collider_components, collider_entity_indices
        }

        if _mem.game.play.recompute_colliders {
            transform_components, transform_entity_indices, collider_components, collider_entity_indices = check_update_components()
        }

        update_timers: {
            mess_creator_components, mess_creator_entity_indices, mess_creator_components_err := engine.entity_get_components(Component_Mess_Creator)
            assert(mess_creator_components_err == .None)

            for entity, i in mess_creator_entity_indices {
                mess_creator := &mess_creator_components[i]
                if mess_creator.on_timer && time.now()._nsec > mess_creator.timer_at._nsec {
                    mess_creator.timer_at = time.time_add(time.now(), mess_creator.timer_cooldown)

                    transform := engine.entity_get_component(entity, engine.Component_Transform)
                    entity_create_mess(fmt.tprintf("Mess from %v", engine.entity_get_name(entity)), transform.position)
                    _mem.game.play.recompute_colliders = true
                    // log.debugf("mess created at² %v", transform.position)
                }
            }
        }

        if _mem.game.play.recompute_colliders {
            transform_components, transform_entity_indices, collider_components, collider_entity_indices = check_update_components()
        }

        player_moved := false
        player_update: {
            if _mem.game.player_inputs.modifier == {} {
                player_move := Vector2f32 {}
                if _mem.game.player_inputs.move != {} {
                    player_move = _mem.game.player_inputs.move
                }

                if player_move != {} {
                    move_rate := (player_move * frame_stat.delta_time * time_scale) / 10
                    next_box := player_collider.box + { move_rate.x, move_rate.y, 0, 0 }

                    collided_with_wall := false
                    for other_entity, i in collider_entity_indices {
                        other_collider := collider_components[i]
                        if other_entity != _mem.game.play.player && engine.aabb_collides(next_box, other_collider.box) && .Block in other_collider.type {
                            // log.debugf("other_entity: %v", other_entity)
                            collided_with_wall = true
                            break
                        }
                    }
                    is_room_transitioning := _mem.game.play.room_transition != nil && engine.animation_is_done(_mem.game.play.room_transition) == false
                    if collided_with_wall == false && is_room_transitioning == false {
                        player_transform.position = player_transform.position + move_rate
                        player_moved = true

                        player_collider := engine.entity_get_component(_mem.game.play.player, Component_Collider)
                        player_collider.box.x = player_transform.position.x - player_collider.box.z / 2
                        player_collider.box.y = player_transform.position.y - player_collider.box.w / 2
                        // engine.entity_set_component(_mem.game.play.player, Component_Collider {
                        //     box = { player_transform.position.x - GRID_SIZE / 2, player_transform.position.y - GRID_SIZE / 2, GRID_SIZE, GRID_SIZE },
                        // })
                    }
                    // engine.ui_text("player_move:  %v", player_move)
                    // engine.ui_text("collided:     %v", collided_with_wall)
                    // engine.ui_text("player_moved: %v", player_moved)
                }

                if player_moved {
                    water_consume_rate := frame_stat.delta_time * time_scale / 4000
                    _mem.game.play.water_level = math.max(_mem.game.play.water_level - water_consume_rate, 0)

                    in_room_bounds := engine.aabb_point_is_inside_box(player_transform.position, camera_bounds)
                    if in_room_bounds == false {
                        direction_from_center := player_transform.position - current_room_center()
                        room_direction := general_direction(direction_from_center)
                        if room_direction == general_direction(player_move) {
                            // log.debugf("direction_from_center: %v %v", direction_from_center, room_direction)
                            make_room_transition(room_direction)
                        }
                    }
                }
            }
        }

        if _mem.game.play.recompute_colliders {
            transform_components, transform_entity_indices, collider_components, collider_entity_indices = check_update_components()
        }

        interact_bounds := Vector4f32 { player_transform.position.x - INTERACT_RANGE / 2, player_transform.position.y - INTERACT_RANGE / 2, INTERACT_RANGE, INTERACT_RANGE }

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
        if _mem.game.play.recompute_colliders {
            transform_components, transform_entity_indices, collider_components, collider_entity_indices = check_update_components()
        }

        player_interaction: {
            entities_under_mouse := make([dynamic]Entity, context.temp_allocator)
            entities_in_interaction_range := make([dynamic]Entity, context.temp_allocator)
            entities_in_cleaning_range := make([dynamic]Entity, context.temp_allocator)

            for entity, i in collider_entity_indices {
                collider := collider_components[i]
                transform := transform_components[transform_entity_indices[entity]]
                if engine.aabb_point_is_inside_box(mouse_world_position, collider.box) && .Interact in collider.type {
                    // log.debugf("found entity: %v", entity)
                    append(&entities_under_mouse, entity)
                }
                if engine.aabb_collides(interact_bounds, collider.box) && .Interact in collider.type {
                    // log.debugf("found entity: %v", entity)
                    append(&entities_in_interaction_range, entity)
                }
                if engine.aabb_collides(interact_bounds, collider.box) && .Clean in collider.type {
                    // log.debugf("found entity: %v", entity)
                    append(&entities_in_cleaning_range, entity)
                }
            }

            // engine.ui_text("entities_in_interaction_range: %v", entities_in_interaction_range)
            // engine.ui_text("entities_under_mouse:          %v", entities_under_mouse)

            player_is_interacting := engine.mouse_button_is_down(.Left) && engine.ui_is_any_window_hovered() == false
            if _mem.game.player_inputs.confirm.down {
                player_is_interacting = true
            }
            if player_is_interacting {
                for entity in entities_in_interaction_range {
                    entity_interact(entity)
                }
            }

            player_is_cleaning := _mem.game.play.water_level > 0
            if player_is_cleaning && player_moved {
                for entity in entities_in_cleaning_range {
                    entity_clean(entity)
                }
            }
        }
        if _mem.game.play.recompute_colliders {
            transform_components, transform_entity_indices, collider_components, collider_entity_indices = check_update_components()
        }

        when DEBUG_UI_ENABLE {
            engine.ui_text("camera_bounds_visible: %v", camera_bounds_visible)
            engine.r_draw_line(_mem.game.world_camera.view_projection_matrix * v4({ 0,0 }), _mem.game.world_camera.view_projection_matrix * v4(mouse_world_position / 2), { 1, 1, 0, 1 })
            engine.r_draw_line(_mem.game.world_camera.view_projection_matrix * v4({ 0,0 }), _mem.game.world_camera.view_projection_matrix * v4(player_transform.position / 2), { 1, 1, 1, 1 })

            for entity, i in collider_entity_indices {
                collider := collider_components[i]
                color := Color { 0, 0.5, 0, 1 }
                if .Block in collider.type {
                    color.r = 1
                }
                if .Interact in collider.type {
                    color.b = 1
                }
                engine.r_draw_rect(collider.box, color, camera.view_projection_matrix)
            }

            engine.r_draw_rect(camera_bounds_visible, { 0, 1, 0, 1 }, camera.view_projection_matrix)
            engine.r_draw_rect(interact_bounds, { 0, 0, 1, 1 }, camera.view_projection_matrix)

            engine.ui_text("camera_bounds:   %v", camera_bounds)
            engine.ui_text("player_position: %v", player_transform.position)
            engine.ui_text("player_bounds:   %v", player_collider.box)
        }

        // update_draw_line()

        _mem.game.play.recompute_colliders = false
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
        // FIXME: put everything invite _mem.game.play on the game_mode arena!
        clear(&_mem.game.play.entities)
        engine.entity_reset_memory()
    }
}

make_room_transition :: proc(normalized_direction: Vector2i32) {
    context.allocator = _mem.game.arena.allocator

    if _mem.game.play.room_transition != nil {
        if engine.animation_is_done(_mem.game.play.room_transition) == false {
            log.warnf("Room transition in progress, skipping...")
            return
        }
        engine.animation_delete_animation(_mem.game.play.room_transition)
    }

    current_room := _mem.game.play.levels[_mem.game.play.current_level_index]
    next_room_index := position_to_room_index(current_room.position + current_room.size * normalized_direction)
    next_room := _mem.game.play.levels[next_room_index]
    // log.debugf("room_index: %v -> %v | position: %v -> %v", _mem.game.play.current_level_index, next_room_index, current_room.position, next_room.position)

    origin := _mem.game.world_camera.position
    destination := engine.vector_i32_to_f32(next_room.position * GRID_SIZE / 2)
    _mem.game.play.current_level_index = next_room_index
    // log.debugf("origin: %v -> destination: %v", origin, destination)

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

general_direction :: proc(direction: Vector2f32) -> Vector2i32 {
    normalized_direction := linalg.normalize(direction)
    if abs(normalized_direction.x) > abs(normalized_direction.y) {
        if normalized_direction.x > 0 {
            return { +1, 0 }
        }
        return { -1, 0 }
    }
    if normalized_direction.y > 0 {
        return { 0, +1 }
    }
    return { 0, -1 }
}
@(test) test_find_path :: proc(t: ^testing.T) {
    context.logger = log.create_console_logger(.Debug, { .Level, .Terminal_Color })
    testing.expect(t, general_direction({ +1, 0 }) == { +1, 0 })
    testing.expect(t, general_direction({ -1, 0 }) == { -1, 0 })
    testing.expect(t, general_direction({ 0, +1 }) == { 0, +1 })
    testing.expect(t, general_direction({ 0, -1 }) == { 0, -1 })
}

current_room_center :: proc() -> Vector2f32 {
    current_room := _mem.game.play.levels[_mem.game.play.current_level_index]
    room_center := engine.vector_i32_to_f32(current_room.position + current_room.size / 2) * GRID_SIZE
    return room_center
}

position_to_room_index :: proc(position: Vector2i32) -> int {
    for level, i in _mem.game.play.levels {
        if level.position == position {
            return i
        }
    }
    return 0
}


entity_clean :: proc(entity: Entity) {
    frame_stat := engine.get_frame_stat()
    time_scale := engine.get_time_scale()

    mess, mess_err := engine.entity_get_component_err(entity, Component_Mess)
    if mess_err == .None {
        mess.clean_progress += frame_stat.delta_time * time_scale * 0.001

        sprite := engine.entity_get_component(entity, engine.Component_Sprite)
        sprite.tint.a = math.clamp(1 - mess.clean_progress, 0, 1)

        if mess.clean_progress >= 1 {
            entity_kill(entity)
        }
    }
}

entity_interact :: proc(entity: Entity) {
    frame_stat := engine.get_frame_stat()
    time_scale := engine.get_time_scale()

    dead, dead_err := engine.entity_get_component_err(entity, Component_Dead)
    if dead_err == .None {
        log.debugf("Interact target is dead: %v", entity)
        return
    }

    pet, pet_err := engine.entity_get_component_err(entity, Component_Pet)
    if pet_err == .None && time.now()._nsec > pet.can_pet_at._nsec {
        pet.can_pet_at = time.time_add(time.now(), PET_COOLDOWN)
        log.warnf("TODO: petting animation")
        // Notes: for now, petting an entity will also kill it, for debug purposes, sorry!
        entity_kill(entity)
    }

    refill, refill_err := engine.entity_get_component_err(entity, Component_Refill)
    if refill_err == .None {
        _mem.game.play.water_level = WATER_LEVEL_MAX
    }
}

entity_kill :: proc(entity: Entity) {
    mess_creator, mess_creator_err := engine.entity_get_component_err(entity, Component_Mess_Creator)
    dead, dead_err := engine.entity_get_component_err(entity, Component_Dead)
    if dead_err == .Component_Not_Found {
        log.errorf("killed entity: %v", entity)

        if mess_creator_err == .None && mess_creator.on_death {
            transform := engine.entity_get_component(entity, engine.Component_Transform)
            new_entity := entity_create_mess(fmt.tprintf("Mess from %v", engine.entity_get_name(entity)), transform.position)
        }

        {
            // TODO: animate death
            engine.entity_set_component(entity, Component_Dead {})

            engine.entity_set_component(entity, engine.Component_Sprite {})
            engine.entity_set_component(entity, Component_Collider {})

            // FIXME: right now our system crashes if we delete the entity before the render, maybe we can do it safely at the end of the frame?
            // engine.entity_delete_entity(entity)
        }

        _mem.game.play.recompute_colliders = true
    }
}

entity_create_slime :: proc(name: string, position: Vector2f32) -> Entity {
    entity := engine.entity_create_entity(name)
    engine.entity_set_component(entity, engine.Component_Transform {
        position = position,
        scale = { 1, 1 },
    })
    component_slime, component_slime_err := engine.entity_set_component(entity, engine.Component_Sprite {
        texture_asset = _mem.game.asset_image_spritesheet,
        texture_size = GRID_SIZE_V2,
        texture_position = grid_position(0, 6),
        texture_padding = TEXTURE_PADDING,
        z_index = i32(len(Level_Layers)) - i32(Level_Layers.Entities),
        tint = { 1, 1, 1, 1 },
        shader_asset = _mem.game.asset_shader_sprite,
    })
    engine.entity_set_component(entity, Component_Collider {
        box = { position.x - GRID_SIZE / 2, position.y - GRID_SIZE / 2, GRID_SIZE, GRID_SIZE },
        type = { .Block, .Interact },
    })
    component_messy, component_messy_err := engine.entity_set_component(entity, Component_Mess_Creator {})
    component_pet, component_pet_err := engine.entity_set_component(entity, Component_Pet {})

    return entity
}

entity_create_mess :: proc(name: string, position: Vector2f32) -> Entity {
    entity := engine.entity_create_entity(name)
    engine.entity_set_component(entity, engine.Component_Transform {
        position = position,
        scale = { 1, 1 },
    })
    engine.entity_set_component(entity, Component_Collider {
        box = { position.x - GRID_SIZE / 2, position.y - GRID_SIZE / 2, GRID_SIZE, GRID_SIZE },
        type = { .Clean },
    })
    component_slime, component_slime_err := engine.entity_set_component(entity, engine.Component_Sprite {
        texture_asset = _mem.game.asset_image_tileset,
        texture_size = GRID_SIZE_V2,
        texture_position = grid_position(21, 7),
        texture_padding = TEXTURE_PADDING,
        tint = { 1, 1, 1, 1 },
        z_index = i32(len(Level_Layers)) - i32(Level_Layers.Entities),
        shader_asset = _mem.game.asset_shader_sprite,
    })
    component_messy, component_messy_err := engine.entity_set_component(entity, Component_Mess {})

    return entity
}
