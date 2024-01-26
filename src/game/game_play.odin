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

INTERACT_RANGE                  :: f32(32)
INTERACT_ATTACK_SPEED           :: f32(5)
PET_COOLDOWN                    :: 1500 * time.Millisecond
LOOT_COOLDOWN                   :: 500 * time.Minute
ADVENTURER_MESS_COOLDOWN        :: 3 * time.Second
ADVENTURER_SPEED                :: 5
ADVENTURER_ATTACK_RANGE         :: 16
PLAYER_SPEED                    :: 5
LEVEL_DURATION                  :: time.Duration(2 * time.Minute)
WATER_LEVEL_MAX                 :: 1
WATER_CONSUMPTION_RATE          :: f32(1)
CLEANING_RATE                   :: f32(5)
CLEANER_MODE_SPEED_MULTIPLIER   :: f32(2)
CLEANER_MODE_CLEAN_MULTIPLIER   :: f32(2)
CLEANER_MODE_WATER_MULTIPLIER   :: f32(3)

levels := [][]string {
    {
        "Room_7",
        "Room_8",
        "Room_9",
    },
    {
        "Room_0",
        "Room_1",
        "Room_2",
        "Room_3",
        "Room_4",
        "Room_5",
    },
}

Play_State :: struct {
    entered_at:             time.Time,
    entities:               [dynamic]Entity,
    player:                 Entity,
    adventurer:             Entity,
    bucket:                 Entity,
    last_door:              Entity,
    levels:                 []^Level,
    current_room_index:    int,
    room_transition:        ^engine.Animation,
    colliders:              [dynamic]Vector4f32,
    recompute_colliders:    bool,
    time_remaining:         time.Duration,
    nodes:                  map[Vector2i32]Node,
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

        _mem.game.render_command_clear.pass_action.colors[0].clear_value = { 0.306, 0.094, 0.486, 1 }

        asset_info, asset_info_ok := engine.asset_get_asset_info_map(_mem.game.asset_map_rooms)
        assert(asset_info_ok, "asset not loaded")

        rooms := levels[_mem.game.current_level]
        _mem.game.play.levels = make_levels(asset_info, rooms, TEXTURE_PADDING, _mem.game.arena.allocator)

        generate_levels_nodes()

        player_spawn_level_index := 0

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
            position := player_spawn_position
            component_transform, component_transform_err := engine.entity_set_component(entity, engine.Component_Transform {
                position = position,
                scale = { 1.5, 1.5 },
            })
            component_sprite, component_sprite_err := engine.entity_set_component(entity, engine.Component_Sprite {
                texture_asset = _mem.game.asset_image_player,
                texture_size = { 24, 24 },
                texture_position = { 0, 0 },
                texture_padding = TEXTURE_PADDING,
                z_index = i32(len(Level_Layers)) - i32(Level_Layers.Entities),
                tint = { 1, 1, 1, 1 },
                shader_asset = _mem.game.asset_shader_sprite,
            })
            collider_size := Vector2f32 { 13, 11 }
            engine.entity_set_component(entity, Component_Collider {
                type   = {  },
                box    = { position.x - collider_size.x / 2, position.y - collider_size.y / 2, collider_size.x, collider_size.y },
                offset = { -0.5, 8 },
            })
            // engine.entity_set_component(entity, Component_Interactive_Adventurer { type = .Attack })
            engine.entity_set_component(entity, Component_Move {})
            engine.entity_set_component(entity, Component_Cleaner {})
            append(&_mem.game.play.entities, entity)
            {
                idle_down_ase := new(Aseprite_Animation)
                idle_down_ase.frames["idle_down_0"] = { duration = 100, frame = { x = 0, y = 0, w = 24, h = 24 } }
                idle_down_anim := make_aseprite_animation(idle_down_ase, &component_sprite.texture_position)
                animation_add_flip(idle_down_anim, &component_transform.scale, component_transform.scale * { 1, 1 })

                idle_right_ase := new(Aseprite_Animation)
                idle_right_ase.frames["idle_right_0"] = { duration = 100, frame = { x = 24, y = 0, w = 24, h = 24 } }
                idle_right_anim := make_aseprite_animation(idle_right_ase, &component_sprite.texture_position)
                animation_add_flip(idle_right_anim, &component_transform.scale, component_transform.scale * { 1, 1 })

                idle_left_anim := make_aseprite_animation(idle_right_ase, &component_sprite.texture_position)
                animation_add_flip(idle_left_anim, &component_transform.scale, component_transform.scale * { -1, 1 })

                idle_up_ase := new(Aseprite_Animation)
                idle_up_ase.frames["idle_up_0"] = { duration = 100, frame = { x = 48, y = 0, w = 24, h = 24 } }
                idle_up_anim := make_aseprite_animation(idle_up_ase, &component_sprite.texture_position)
                animation_add_flip(idle_up_anim, &component_transform.scale, component_transform.scale * { 1, 1 })

                engine.entity_set_component(entity, Component_Animator {
                    animations = { "idle_down" = idle_down_anim, "idle_right" = idle_right_anim, "idle_left" = idle_left_anim, "idle_up" = idle_up_anim },
                })
                entity_change_animation(entity, "idle_down")
            }
            _mem.game.play.player = entity

            for level, i in _mem.game.play.levels {
                current_room_bounds := Vector4f32 { f32(level.position.x) * GRID_SIZE, f32(level.position.y) * GRID_SIZE, f32(level.size.x) * GRID_SIZE, f32(level.size.y) * GRID_SIZE }
                if engine.aabb_point_is_inside_box(position, current_room_bounds) {
                    player_spawn_level_index = i
                    break
                }
            }
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
                texture_position = grid_position(0, 6),
                texture_padding = TEXTURE_PADDING,
                z_index = i32(len(Level_Layers)) - i32(Level_Layers.Entities),
                tint = { 1, 1, 1, 1 },
                shader_asset = _mem.game.asset_shader_sprite,
            })
            collider_size := Vector2f32 { 12, 10 }
            engine.entity_set_component(entity, Component_Collider {
                type   = { .Block, .Interact },
                box    = { position.x - collider_size.x / 2, position.y - collider_size.y / 2, collider_size.x, collider_size.y },
                offset = { 1, 2 },
            })
            engine.entity_set_component(entity, Component_Interactive_Primary { type = .Refill_Water })
            engine.entity_set_component(entity, Component_Interactive_Secondary { type = .Carry })
            append(&_mem.game.play.entities, entity)
            _mem.game.play.bucket = entity
        }

        { entity := engine.entity_create_entity("Ad Venturer")
            component_transform, component_transform_err := engine.entity_set_component(entity, engine.Component_Transform {
                position = adv_spawn_position,
                scale = { 2, 2 },
            })
            component_sprite, component_sprite_err := engine.entity_set_component(entity, engine.Component_Sprite {
                texture_asset = _mem.game.asset_image_adventurer,
                texture_size = { 32, 32 },
                texture_position = { 0, 0 },
                texture_padding = TEXTURE_PADDING,
                z_index = i32(len(Level_Layers)) - i32(Level_Layers.Entities),
                tint = { 1, 1, 1, 1 },
                shader_asset = _mem.game.asset_shader_sprite,
            })
            position := component_transform.position
            collider_size := Vector2f32 { 80, 80 }
            engine.entity_set_component(entity, Component_Collider {
                type   = { .Interact },
                box    = { position.x - collider_size.x / 2, position.y - collider_size.y / 2, collider_size.x, collider_size.y },
            })
            engine.entity_set_component(entity, Component_Adventurer { mode = .Idle })
            engine.entity_set_component(entity, Component_Move { })
            {
                walk_left_ase := new(Aseprite_Animation)
                walk_left_ase.frames["frame_0"] = { duration = 100, frame = { x = 0, y = 0, w = 32, h = 32 } }
                walk_left_ase.frames["frame_1"] = { duration = 100, frame = { x = 32, y = 0, w = 32, h = 32 } }
                walk_left_ase.frames["frame_2"] = { duration = 100, frame = { x = 64, y = 0, w = 32, h = 32 } }
                walk_left_ase.frames["frame_3"] = { duration = 100, frame = { x = 96, y = 0, w = 32, h = 32 } }
                walk_left_anim := make_aseprite_animation(walk_left_ase, &component_sprite.texture_position)
                animation_add_flip(walk_left_anim, &component_transform.scale, component_transform.scale * { 1, 1 })

                walk_right_anim := make_aseprite_animation(walk_left_ase, &component_sprite.texture_position)
                animation_add_flip(walk_right_anim, &component_transform.scale, component_transform.scale * { -1, 1 })

                engine.entity_set_component(entity, Component_Animator {
                    animations = { "walk_left" = walk_left_anim, "walk_right" = walk_right_anim },
                })
                entity_change_animation(entity, "walk_left")
            }
            append(&_mem.game.play.entities, entity)
            _mem.game.play.adventurer = entity
        }

        _mem.game.play.current_room_index = player_spawn_level_index
        current_room := _mem.game.play.levels[_mem.game.play.current_room_index]
        // _mem.game.world_camera.zoom = CAMERA_ZOOM_INITIAL
        _mem.game.world_camera.position = engine.vector_i32_to_f32(current_room.position * GRID_SIZE / 2)

        _mem.game.play.time_remaining = LEVEL_DURATION
        _mem.game.score = 0

        player_cleaner := engine.entity_get_component(_mem.game.play.player, Component_Cleaner)
        player_cleaner.water_level = WATER_LEVEL_MAX
    }


    if game_mode_running() {
        // @(static) transition: i32
        // if transition == 0 && scene_transition_is_done() {
        //     transition = 1
        //     scene_transition_start(.Unswipe_Left_To_Right)
        //     return
        // }

        // if scene_transition_is_done() == false {
        //     return
        // }

        player_transform := engine.entity_get_component(_mem.game.play.player, engine.Component_Transform)
        player_collider := engine.entity_get_component(_mem.game.play.player, Component_Collider)
        player_animator := engine.entity_get_component(_mem.game.play.player, Component_Animator)
        player_cleaner := engine.entity_get_component(_mem.game.play.player, Component_Cleaner)
        // current_room := _mem.game.play.levels[_mem.game.play.current_room_index]

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
        player_move := Vector2f32 {}
        player_update: {
            {
                if _mem.game.player_inputs.move != {} {
                    player_move = _mem.game.player_inputs.move
                }

                if player_move != {} {
                    velocity := player_move * PLAYER_SPEED
                    if player_cleaner.mode == .Speed && player_cleaner.water_level > 0 {
                        velocity *= CLEANER_MODE_SPEED_MULTIPLIER
                    }
                    delta := calculate_frame_velocity(velocity)
                    next_position := player_transform.position + delta

                    next_box_x := player_collider.box + { delta.x, 0, 0, 0 }
                    next_box_y := player_collider.box + { 0, delta.y, 0, 0 }

                    collided_with_wall_x := false
                    collided_with_wall_y := false
                    for other_entity, i in collider_entity_indices {
                        other_collider := collider_components[i]

                        if collided_with_wall_x && collided_with_wall_y {
                            break
                        }

                        if collided_with_wall_x == false && other_entity != _mem.game.play.player && engine.aabb_collides(next_box_x, other_collider.box) && .Block in other_collider.type {
                            collided_with_wall_x = true
                            velocity.x = 0
                        }
                        if collided_with_wall_y == false && other_entity != _mem.game.play.player && engine.aabb_collides(next_box_y, other_collider.box) && .Block in other_collider.type {
                            collided_with_wall_y = true
                            velocity.y = 0
                        }
                    }

                    // engine.r_draw_line(v4(box_center(player_collider.box) / 2 + player_move * 10), v4(box_center(player_collider.box) / 2), { 1, 1, 1, 1 })

                    is_room_transitioning := _mem.game.play.room_transition != nil && engine.animation_is_done(_mem.game.play.room_transition) == false
                    if is_room_transitioning == false {
                        apply_velocity(&player_transform.position, velocity)
                        if velocity != {} {
                            update_animator(_mem.game.play.player, velocity, player_animator)
                        } else {
                            update_animator(_mem.game.play.player, player_move, player_animator)
                        }
                        player_moved = true
                    }
                }

                if player_moved {
                    player_carrier, player_carrier_err := engine.entity_get_component_err(_mem.game.play.player, Component_Carrier)
                    if player_carrier_err == .Component_Not_Found {
                        water_consume_rate := frame_stat.delta_time * time_scale * 0.0001 * WATER_CONSUMPTION_RATE
                        if player_cleaner.mode == .Speed && player_cleaner.water_level > 0 {
                            water_consume_rate *= CLEANER_MODE_WATER_MULTIPLIER
                        }
                        player_cleaner.water_level = math.max(player_cleaner.water_level - water_consume_rate, 0)
                        if player_cleaner.water_level <= 0 {
                            player_cleaner.mode = .Default
                        }
                    }

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

        adventurer_update: {
            entity := _mem.game.play.adventurer
            adv_adventurer := engine.entity_get_component(entity, Component_Adventurer)
            adv_transform := &transform_components[transform_entity_indices[entity]]
            adv_collider := &collider_components[collider_entity_indices[entity]]
            adv_move := engine.entity_get_component(entity, Component_Move)
            adv_animator := engine.entity_get_component(entity, Component_Animator)
            previous_velocity := adv_move.velocity

            switch adv_adventurer.mode {
                case .Idle: {
                    adv_move.velocity = {}

                    player_room := get_room_index_by_position(world_to_grid_position(player_transform.position))
                    adventurer_room := get_room_index_by_position(world_to_grid_position(adv_transform.position))

                    if player_room == adventurer_room {
                        adv_adventurer.mode = .Thinking
                    }
                }
                case .Thinking: {
                    log.debugf("Adventurer thinking...")

                    adv_room := get_room_index_by_position(world_to_grid_position(adv_transform.position))

                    { // Kills slimes
                        closest_target := engine.ENTITY_INVALID
                        closest_position := Vector2f32 { 9999, 9999 }
                        for other_entity, i in collider_entity_indices {
                            other_collider := collider_components[i]
                            other_transform := transform_components[transform_entity_indices[other_entity]]

                            if .Target in other_collider.type {
                                other_room := get_room_index_by_position(world_to_grid_position(other_transform.position))
                                other_interactive, other_interactive_err := engine.entity_get_component_err(other_entity, Component_Interactive_Adventurer)
                                if adv_room == other_room && linalg.distance(adv_transform.position, other_transform.position) < linalg.distance(adv_transform.position, closest_position) && other_interactive_err == .None && other_interactive.type == .Attack {
                                    closest_target = other_entity
                                    closest_position = other_transform.position
                                    // log.debugf("found closest: %v (%v)", engine.entity_get_name(other_entity), other_transform.position)
                                }
                            }
                        }

                        if closest_target != engine.ENTITY_INVALID {
                            start := world_to_grid_position(adv_transform.position)
                            end := world_to_grid_position(closest_position)
                            path, path_ok := find_path(start, end)
                            if path_ok {
                                adv_move.path = path
                                adv_move.path_current = 0
                                adv_adventurer.mode = .Move
                                // log.debugf("found slime")
                                break
                            } else {
                                log.errorf("Couldn't find path to closest target...")
                            }
                        }
                    }

                    { // Loot chests
                        closest_target := engine.ENTITY_INVALID
                        closest_position := Vector2f32 { 9999, 9999 }
                        for other_entity, i in collider_entity_indices {
                            other_collider := collider_components[i]
                            other_transform := transform_components[transform_entity_indices[other_entity]]

                            if .Target in other_collider.type {
                                other_room := get_room_index_by_position(world_to_grid_position(other_transform.position))
                                other_interactive, other_interactive_err := engine.entity_get_component_err(other_entity, Component_Interactive_Adventurer)
                                if adv_room == other_room && linalg.distance(adv_transform.position, other_transform.position) < linalg.distance(adv_transform.position, closest_position) && other_interactive_err == .None && other_interactive.type == .Loot {
                                    other_loot := engine.entity_get_component(other_entity, Component_Loot)
                                    if other_loot.looted == false {
                                        closest_target = other_entity
                                        closest_position = other_transform.position
                                        // log.debugf("found closest: %v (%v)", engine.entity_get_name(other_entity), other_transform.position)
                                    }
                                }
                            }
                        }

                        if closest_target != engine.ENTITY_INVALID {
                            start := world_to_grid_position(adv_transform.position)
                            end := world_to_grid_position(closest_position)
                            path, path_ok := find_path(start, end)
                            if path_ok {
                                adv_move.path = path
                                adv_move.path_current = 0
                                adv_adventurer.mode = .Move
                                // log.debugf("found chest")
                                break
                            } else {
                                log.errorf("Couldn't find path to closest target...")
                            }
                        }
                    }

                    { // Search for exit to next room
                        closest_target := engine.ENTITY_INVALID
                        closest_position := Vector2f32 { 9999, 9999 }
                        for other_entity, i in collider_entity_indices {
                            other_collider := collider_components[i]
                            other_transform := transform_components[transform_entity_indices[other_entity]]

                            if .Exit in other_collider.type {
                                other_room := get_room_index_by_position(world_to_grid_position(other_transform.position))
                                if adv_room == other_room {
                                    closest_target = other_entity
                                    closest_position = other_transform.position
                                    // log.debugf("found closest: %v (%v)", engine.entity_get_name(other_entity), other_transform.position)
                                }
                            }
                        }

                        if closest_target != engine.ENTITY_INVALID {
                            exit := engine.entity_get_component(closest_target, Component_Exit)
                            start := world_to_grid_position(adv_transform.position)
                            end := world_to_grid_position(closest_position) + exit.direction * 5
                            path, path_ok := find_path(start, end)
                            if path_ok {
                                adv_move.path = path
                                adv_move.path_current = 0
                                adv_adventurer.mode = .Move
                                // log.debugf("found exit")
                                break
                            } else {
                                log.errorf("Couldn't find path to closest target...")
                            }
                        }
                    }

                    log.errorf("Nothing to do, going into .Idle")
                    adv_adventurer.mode = .Idle

                    entity_close_door(_mem.game.play.last_door)
                }
                case .Move: {
                    if len(adv_move.path) == 0 {
                        adv_adventurer.mode = .Thinking
                        break
                    }
                    if adv_move.path_current >= len(adv_move.path) {
                        adv_move.path = {}
                        adv_move.path_current = 0
                        adv_move.velocity = { 0, 0 }
                        break
                    }

                    path_destination_grid := adv_move.path[adv_move.path_current]
                    path_destination := grid_to_world_position_center(path_destination_grid, { 16, 4 })
                    path_distance := path_destination - adv_transform.position

                    if linalg.distance(path_destination, adv_transform.position) < 1 {
                        adv_move.path_current += 1
                        break
                    }

                    direction := linalg.normalize(path_distance)
                    if direction != {} {
                        adv_move.velocity = direction * ADVENTURER_SPEED
                    }

                    last_door_transform := engine.entity_get_component(_mem.game.play.last_door, engine.Component_Transform)
                    if linalg.length(last_door_transform.position - adv_transform.position) < 15 {
                        entity_open_door(_mem.game.play.last_door)
                    }

                    for other_entity, i in collider_entity_indices {
                        other_collider := collider_components[i]
                        if other_entity != entity && engine.aabb_collides(adv_collider.box, other_collider.box) && .Target in other_collider.type {
                            interactive := engine.entity_get_component(other_entity, Component_Interactive_Adventurer)
                            if interactive.cooldown_end._nsec < time.now()._nsec {
                                adv_adventurer.mode = .Combat
                                adv_adventurer.target = other_entity
                                break
                            }
                        }
                    }

                    if linalg.length(path_distance) < 1 {
                        log.debugf("stop?")
                    }
                }
                case .Combat: {
                    if adv_adventurer.target == engine.ENTITY_INVALID {
                        log.errorf("in combat with no target?")
                        adv_adventurer.mode = .Move
                        break
                    }

                    adv_move.velocity = {}

                    target_collider := &collider_components[collider_entity_indices[adv_adventurer.target]]
                    target_transform := &transform_components[transform_entity_indices[adv_adventurer.target]]

                    diff := target_transform.position - adv_transform.position
                    is_in_range := linalg.length(diff) < ADVENTURER_ATTACK_RANGE
                    if is_in_range == false {
                        distance_current := linalg.length(target_collider.box.xy - adv_collider.box.xy)

                        closest_target := engine.ENTITY_INVALID
                        for other_entity, i in collider_entity_indices {
                            other_collider := collider_components[i]
                            if other_entity != entity && engine.aabb_collides(adv_collider.box, other_collider.box) && .Target in other_collider.type {
                                distance_new := linalg.length(other_collider.box.xy - adv_collider.box.xy)
                                if distance_new < distance_current {
                                    interactive := engine.entity_get_component(other_entity, Component_Interactive_Adventurer)
                                    if interactive.cooldown_end._nsec < time.now()._nsec {
                                        closest_target = other_entity
                                    }
                                }
                            }
                        }

                        if closest_target != engine.ENTITY_INVALID {
                            adv_adventurer.target = closest_target
                        }

                        direction := linalg.normalize(diff)
                        adv_move.velocity = direction * ADVENTURER_SPEED

                        break
                    }

                    interactive, interactive_err := engine.entity_get_component_err(adv_adventurer.target, Component_Interactive_Adventurer)
                    if interactive_err == .None {
                        entity_interact(adv_adventurer.target, entity, cast(^Component_Interactive) interactive)
                    } else {
                        log.warnf("adventurer trying to interact with entity missing Component_Interactive_Adventurer: %v", adv_adventurer.target)
                    }

                    if interactive.done {
                        adv_adventurer.mode = .Thinking
                    }
                }
            }

            apply_velocity(&adv_transform.position, adv_move.velocity)
            update_animator(entity, adv_move.velocity, adv_animator, true)
        }

        if _mem.game.play.recompute_colliders {
            transform_components, transform_entity_indices, collider_components, collider_entity_indices = check_update_components()
        }

        player_interaction: {
            entities_under_mouse := make([dynamic]Entity, context.temp_allocator)
            entities_in_interaction_range := make([dynamic]Entity, context.temp_allocator)
            entities_in_cleaning_range := make([dynamic]Entity, context.temp_allocator)

            for entity, i in collider_entity_indices {
                collider := &collider_components[i]
                transform := &transform_components[transform_entity_indices[entity]]

                // FIXME:
                collider.box.x = transform.position.x - collider.box.z / 2 + collider.offset.x
                collider.box.y = transform.position.y - collider.box.w / 2 + collider.offset.y

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

            when DEBUG_UI_ENABLE {
                engine.ui_text("entities_in_interaction_range: %v", entities_in_interaction_range)
                engine.ui_text("entities_in_cleaning_range:    %v", entities_in_cleaning_range)
                engine.ui_text("entities_under_mouse:          %v", entities_under_mouse)
            }

            if _mem.game.player_inputs.dash.down {
                player_cleaner.mode = .Speed
            } else {
                player_cleaner.mode = .Default
            }

            player_carrier, player_carrier_err := engine.entity_get_component_err(_mem.game.play.player, Component_Carrier)

            Interactions :: enum { None, Primary, Secondary }
            interaction := Interactions.None
            if engine.mouse_button_is_released(.Left) && engine.ui_is_any_window_hovered() == false {
                interaction = .Primary
            }
            if _mem.game.player_inputs.confirm.released {
                interaction = .Primary
            }
            if engine.mouse_button_is_released(.Right) && engine.ui_is_any_window_hovered() == false {
                interaction = .Secondary
            }
            if _mem.game.player_inputs.cancel.released {
                interaction = .Secondary
            }

            if interaction != .None {
                if player_carrier_err == .Component_Not_Found { // Can't interact while carrying stuff
                    for entity in entities_in_interaction_range {
                        if interaction == .Primary {
                            interactive, interactive_err := engine.entity_get_component_err(entity, Component_Interactive_Primary)
                            if interactive_err == .None {
                                player_cleaner.mode = .Default
                                entity_interact(entity, _mem.game.play.player, cast(^Component_Interactive) interactive)
                                break
                            }
                        } else if interaction == .Secondary {
                            interactive, interactive_err := engine.entity_get_component_err(entity, Component_Interactive_Secondary)
                            if interactive_err == .None {
                                player_cleaner.mode = .Default
                                entity_interact(entity, _mem.game.play.player, cast(^Component_Interactive) interactive)
                                break
                            }
                        }
                    }
                } else {
                    if interaction == .Secondary {
                        entity_throw(player_carrier.target, _mem.game.play.player, player_animator.direction)
                    }
                }
            }

            if player_carrier_err == .Component_Not_Found { // Can't interact while carrying stuff
                if player_cleaner.water_level > 0 && player_moved {
                    cleaning_speed := CLEANING_RATE
                    if player_cleaner.mode == .Speed && player_cleaner.water_level > 0 {
                        cleaning_speed *= CLEANER_MODE_CLEAN_MULTIPLIER
                    }

                    for other_entity in entities_in_cleaning_range {
                        entity_clean(other_entity, cleaning_speed)
                    }
                }
            }
        }

        self_destruct: {
            self_destruct_components, entity_indices, self_destruct_components_err := engine.entity_get_components(Component_Self_Destruct)
            assert(self_destruct_components_err == .None)

            for entity, i in entity_indices {
                self_destruct_component := &self_destruct_components[i]
                if time.now()._nsec > self_destruct_component.ends_at._nsec {
                    log.debugf("entity self destroyed: %v", entity)
                    engine.entity_delete_entity(entity)
                }
            }
        }

        if _mem.game.play.recompute_colliders {
            transform_components, transform_entity_indices, collider_components, collider_entity_indices = check_update_components()
        }

        when DEBUG_UI_ENABLE {
            engine.ui_text("camera_bounds_visible: %v", camera_bounds_visible)
            // engine.r_draw_line(_mem.game.world_camera.view_projection_matrix * v4({ 0,0 }), _mem.game.world_camera.view_projection_matrix * v4(mouse_world_position / 2), { 1, 1, 0, 1 })
            // engine.r_draw_line(_mem.game.world_camera.view_projection_matrix * v4({ 0,0 }), _mem.game.world_camera.view_projection_matrix * v4(player_transform.position / 2), { 1, 1, 1, 1 })

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

            for position, node in _mem.game.play.nodes {
                color := Color { 0, 0, 0, 1 }
                if .Block in node.cell {
                    color.r = 1
                }
                if .See in node.cell {
                    color.g = 1
                }
                if .Walk in node.cell {
                    color.b = 1
                }
                box := Vector4f32 {
                    1 + 16 * f32(node.position.x),  1 + 16 * f32(node.position.y),
                    14,                             14,
                }
                engine.r_draw_rect(box, color, camera.view_projection_matrix)
            }

            engine.r_draw_rect(camera_bounds_visible, { 0, 1, 0, 1 }, camera.view_projection_matrix)
            engine.r_draw_rect(interact_bounds, { 0, 0, 1, 1 }, camera.view_projection_matrix)

            engine.ui_text("camera_bounds:   %v", camera_bounds)
            engine.ui_text("player_position: %v", player_transform.position)
            engine.ui_text("player_bounds:   %v", player_collider.box)
        }

        // update_draw_line()

        _mem.game.play.recompute_colliders = false

        game_ui_hud()

        {
            delta := time.Duration(frame_stat.delta_time * time_scale * f32(time.Millisecond))
            _mem.game.play.time_remaining = math.max(_mem.game.play.time_remaining - delta, 0)

            if _mem.game.play.time_remaining == 0 {
                game_mode_transition(.Game_Over)
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
        // FIXME: put everything invite _mem.game.play on the game_mode arena!
        clear(&_mem.game.play.entities)
        engine.entity_reset_memory()
        engine.animation_reset_memory()

        mem.zero(&_mem.game.play, size_of(_mem.game.play))
    }
}

make_room_transition :: proc(normalized_direction: Vector2i32) {
    // log.debugf("make_room_transition: %v", normalized_direction)
    context.allocator = _mem.game.arena.allocator

    _mem.game.free_look = false

    if _mem.game.play.room_transition != nil {
        if engine.animation_is_done(_mem.game.play.room_transition) == false {
            log.warnf("Room transition in progress, skipping...")
            return
        }
        engine.animation_delete_animation(_mem.game.play.room_transition)
    }

    current_room := _mem.game.play.levels[_mem.game.play.current_room_index]
    next_room_position := current_room.position + current_room.size * normalized_direction
    next_room_index := position_to_room_index(next_room_position)
    next_room := _mem.game.play.levels[next_room_index]
    // log.debugf("room_index: %v -> %v | position: %v -> %v", _mem.game.play.current_room_index, next_room_index, current_room.position, next_room.position)

    origin := _mem.game.world_camera.position
    destination := engine.vector_i32_to_f32(next_room.position * GRID_SIZE / 2)
    _mem.game.play.current_room_index = next_room_index
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
    } else if abs(normalized_direction.y) > abs(normalized_direction.x)  {
        if normalized_direction.y > 0 {
            return { 0, +1 }
        } else {
            return { 0, -1 }
        }
    }
    return { 0, 0 }
}
@(test) test_find_path :: proc(t: ^testing.T) {
    context.logger = log.create_console_logger(.Debug, { .Level, .Terminal_Color })
    testing.expect(t, general_direction({ +1, 0 }) == { +1, 0 })
    testing.expect(t, general_direction({ -1, 0 }) == { -1, 0 })
    testing.expect(t, general_direction({ 0, +1 }) == { 0, +1 })
    testing.expect(t, general_direction({ 0, -1 }) == { 0, -1 })
    testing.expect(t, general_direction({ 0, 0 }) == { 0, 0 })
    testing.expect(t, general_direction({ 0.5, 0.5 }) == { 0, 0 })
}

current_room_center :: proc() -> Vector2f32 {
    current_room := _mem.game.play.levels[_mem.game.play.current_room_index]
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


entity_clean :: proc(entity: Entity, cleaning_speed: f32) {
    frame_stat := engine.get_frame_stat()
    time_scale := engine.get_time_scale()

    mess, mess_err := engine.entity_get_component_err(entity, Component_Mess)
    if mess_err == .None {
        mess.progress += frame_stat.delta_time * time_scale * 0.0001 * cleaning_speed

        sprite := engine.entity_get_component(entity, engine.Component_Sprite)
        sprite.tint.a = math.clamp(1 - mess.progress, 0, 1)
        if mess.progress >= 1 {
            _mem.game.score += 300
            entity_kill(entity)
        }
    }
}

entity_throw :: proc(target: Entity, actor: Entity, direction: Direction) {
    log.debugf("throw! %v", engine.entity_get_name(target))

    engine.entity_delete_component(actor, Component_Carrier)

    direction_vector := direction_to_vector(direction)

    actor_transform := engine.entity_get_component(actor, engine.Component_Transform)
    transform := engine.entity_get_component(target, engine.Component_Transform)
    transform.parent = engine.ENTITY_INVALID
    transform.position = actor_transform.position + direction_vector * GRID_SIZE_F32

    sprite_actor := engine.entity_get_component(actor, engine.Component_Sprite)
    sprite := engine.entity_get_component(target, engine.Component_Sprite)
    sprite.z_index = i32(len(Level_Layers) - int(Level_Layers.Entities))
}
entity_interact :: proc(target: Entity, actor: Entity, interactive: ^Component_Interactive) {
    frame_stat := engine.get_frame_stat()
    time_scale := engine.get_time_scale()

    dead, dead_err := engine.entity_get_component_err(target, Component_Dead)
    if dead_err == .None {
        log.debugf("Interact target is dead: %v", target)
        return
    }

    @(static) cloud: Entity

    switch interactive.type {
        case .Invalid: {
            log.errorf("Invalid interactive type!")
        }
        case .Carry: {
            if interactive.done {
                break
            }

            interactive.done = true
            interactive.progress = 0

            transform := engine.entity_get_component(target, engine.Component_Transform)
            transform.parent = actor
            transform.position = { 0, -8 }

            sprite_actor := engine.entity_get_component(actor, engine.Component_Sprite)
            sprite := engine.entity_get_component(target, engine.Component_Sprite)
            sprite.z_index = sprite_actor.z_index + 1

            engine.entity_set_component(actor, Component_Carrier { target = target })

            interactive_primary, interactive_primary_err := engine.entity_get_component_err(target, Component_Interactive_Primary)
            if interactive_primary_err == .None && interactive_primary.type == .Refill_Water {
                refill_water(actor)
            }

            interactive.done = false
        }
        case .Repair_Torch: {
            if interactive.done {
                break
            }
            sprite := engine.entity_get_component(target, engine.Component_Sprite)
            interactive.done = true
            interactive.progress = 0
            entity_change_animation(target, "lit")
            _mem.game.score += 100
            log.debugf("Torch lit")
        }
        case .Repair_Chest: {
            if interactive.done {
                break
            }
            sprite := engine.entity_get_component(target, engine.Component_Sprite)
            interactive.done = true
            interactive.progress = 0
            sprite.texture_position = grid_position(22, 4)
            _mem.game.score += 100
            log.debugf("Chest repaired")
        }
        case .Refill_Water: {
            refill_water(actor)
        }
        case .Pet: {
            if time.diff(interactive.cooldown_end, time.now()) > 0 {
                interactive.done = true
                interactive.progress = 0
                interactive.cooldown_end = time.time_add(time.now(), PET_COOLDOWN)
                // TODO: actor petting animation
                transform := engine.entity_get_component(target, engine.Component_Transform)
                entity_create_heart(transform.position + { 0, -12 })
            }
        }
        case .Attack: {
            if interactive.done {
                break
            }
            if time.diff(interactive.cooldown_end, time.now()) > 0 {
                if interactive.progress == 0 {
                    actor_transform := engine.entity_get_component(actor, engine.Component_Transform)
                    target_transform := engine.entity_get_component(target, engine.Component_Transform)
                    direction := target_transform.position - actor_transform.position
                    cloud = entity_create_cloud(actor_transform.position + direction / 2)
                }
                // TODO: disable target movement when this is happening?
                interactive.progress += frame_stat.delta_time * time_scale * 0.0001 * INTERACT_ATTACK_SPEED
            }
            if interactive.progress >= 1 {
                engine.entity_delete_entity(cloud)
                interactive.done = true
                interactive.progress = 0
                interactive.cooldown_end = time.time_add(time.now(), LOOT_COOLDOWN)
                entity_kill(target)
            }
        }
        case .Loot: {
            if interactive.done {
                break
            }
            if time.diff(interactive.cooldown_end, time.now()) > 0 {
                if interactive.progress == 0 {
                    actor_transform := engine.entity_get_component(actor, engine.Component_Transform)
                    target_transform := engine.entity_get_component(target, engine.Component_Transform)
                    direction := target_transform.position - actor_transform.position
                    cloud = entity_create_cloud(actor_transform.position + direction / 2)
                }

                // TODO: disable target when this is happening?
                interactive.progress += frame_stat.delta_time * time_scale * 0.0001 * INTERACT_ATTACK_SPEED
            }
            if interactive.progress >= 1 {
                engine.entity_delete_entity(cloud)
                interactive.done = true
                interactive.progress = 0
                interactive.cooldown_end = time.time_add(time.now(), LOOT_COOLDOWN)

                sprite := engine.entity_get_component(target, engine.Component_Sprite)
                sprite.texture_position = grid_position(21, 4)

                loot := engine.entity_get_component(target, Component_Loot)
                loot.looted = true
            }
        }
        case .Exit: {
            next_level()
        }
    }
}

entity_kill :: proc(entity: Entity) {
    dead, dead_err := engine.entity_get_component_err(entity, Component_Dead)
    if dead_err == .None {
        return
    }

    mess_creator, mess_creator_err := engine.entity_get_component_err(entity, Component_Mess_Creator)

    if mess_creator_err == .None && mess_creator.on_death {
        transform := engine.entity_get_component(entity, engine.Component_Transform)
        mess_count := rand.int_max(5, &_mem.game.rand) + 2
        for i := 0; i < mess_count; i += 1 {
            position := transform.position + { rand.float32_range(-24, 24, &_mem.game.rand), rand.float32_range(-24, 24, &_mem.game.rand) }
            variant : i32 = rand.int31_max(7, &_mem.game.rand)
            entity_create_mess(fmt.tprintf("Mess from %v", engine.entity_get_name(entity)), position, variant)
        }
    }

    // TODO: animate death
    engine.entity_set_component(entity, Component_Dead {})
    engine.entity_set_component(entity, engine.Component_Sprite {})
    engine.entity_set_component(entity, Component_Collider {})

    if entity == _mem.game.play.player {
        game_mode_transition(.Game_Over)
    }

    // FIXME: right now our system crashes if we delete the entity before the render, maybe we can do it safely at the end of the frame?
    // engine.entity_delete_entity(entity)
    _mem.game.play.recompute_colliders = true
}

entity_create_slime :: proc(name: string, position: Vector2f32, small := false) -> Entity {
    entity := engine.entity_create_entity(name)
    component_transform, component_transform_err := engine.entity_set_component(entity, engine.Component_Transform {
        position = position,
        scale = { 1, 1 },
    })
    component_sprite, component_sprite_err := engine.entity_set_component(entity, engine.Component_Sprite {
        texture_asset = _mem.game.asset_image_spritesheet,
        texture_size = GRID_SIZE_V2,
        // texture_position = grid_position(0, 6),
        texture_padding = TEXTURE_PADDING,
        z_index = i32(len(Level_Layers)) - i32(Level_Layers.Entities),
        tint = { 1, 1, 1, 1 },
        shader_asset = _mem.game.asset_shader_sprite,
    })
    collider_size := Vector2f32 { 12, 10 }
    engine.entity_set_component(entity, Component_Collider {
        type   = { .Block, .Interact, .Target },
        box    = { position.x - collider_size.x / 2, position.y - collider_size.y / 2, collider_size.x, collider_size.y },
        offset = { 1, 2 },
    })
    component_messy, component_messy_err := engine.entity_set_component(entity, Component_Mess_Creator {
        on_death = true,
    })
    engine.entity_set_component(entity, Component_Interactive_Primary { type = .Pet })
    engine.entity_set_component(entity, Component_Interactive_Secondary { type = .Carry })
    engine.entity_set_component(entity, Component_Interactive_Adventurer { type = .Attack })
    {
        offset_x : i32 = small ? 32 : 0
        idle_ase := new(Aseprite_Animation)
        idle_ase.frames["frame_0"] = { duration = 100, frame = { x = offset_x + 0, y = 0, w = 16, h = 16 } }
        idle_ase.frames["frame_1"] = { duration = 100, frame = { x = offset_x + 16, y = 0, w = 16, h = 16 } }
        idle_anim := make_aseprite_animation(idle_ase, &component_sprite.texture_position)
        animation_add_flip(idle_anim, &component_transform.scale, component_transform.scale * { 1, 1 })

        engine.entity_set_component(entity, Component_Animator {
            animations = { "idle" = idle_anim },
        })
        entity_change_animation(entity, "idle")
    }

    return entity
}

entity_create_door :: proc(name: string, position: Vector2f32, opened: bool, direction: Direction, last_door: bool) -> Entity {
    entity := engine.entity_create_entity(name)
    component_transform, component_transform_err := engine.entity_set_component(entity, engine.Component_Transform {
        position = position,
        scale = { 1, 1 },
    })
    component_sprite, component_sprite_err := engine.entity_set_component(entity, engine.Component_Sprite {
        texture_asset = _mem.game.asset_image_tileset,
        texture_size = GRID_SIZE_V2,
        // texture_position = t_position,
        texture_padding = TEXTURE_PADDING,
        z_index = i32(len(Level_Layers)) - i32(Level_Layers.Entities) - 1,
        tint = { 1, 1, 1, 1 },
        shader_asset = _mem.game.asset_shader_sprite,
    })
    engine.entity_set_component(entity, Component_Door { last = last_door, opened = opened, direction = direction })
    if opened == false {
        entity_close_door(entity)
    } else {
        entity_open_door(entity)
    }
    if last_door {
        engine.entity_set_component(entity, Component_Interactive_Primary { type = .Exit })
        _mem.game.play.last_door = entity
    }

    return entity
}

entity_close_door :: proc(entity: Entity) {
    component_transform := engine.entity_get_component(entity, engine.Component_Transform)
    collider_size := Vector2f32 { 16, 16 }
    engine.entity_set_component(entity, Component_Collider {
        type   = { .Block, .Interact },
        box    = { component_transform.position.x - collider_size.x / 2, component_transform.position.y - collider_size.y / 2, collider_size.x, collider_size.y },
    })
    component_sprite := engine.entity_get_component(entity, engine.Component_Sprite)

    component_door := engine.entity_get_component(entity, Component_Door)
    component_door.opened = false
    direction := component_door.direction
    t_position := grid_position(9, 30)
    if direction == .West {  t_position = grid_position(8, 30) }
    if direction == .South { t_position = grid_position(11, 30) }
    if direction == .North { t_position = grid_position(11, 29) }
    component_sprite.texture_position = t_position

    _mem.game.play.recompute_colliders = true
}

entity_open_door :: proc(entity: Entity) {
    component_transform := engine.entity_get_component(entity, engine.Component_Transform)
    engine.entity_delete_component(entity, Component_Collider)
    component_sprite := engine.entity_get_component(entity, engine.Component_Sprite)

    component_door := engine.entity_get_component(entity, Component_Door)
    component_door.opened = true
    direction := component_door.direction
    t_position := grid_position(9, 28)
    if direction == .West {  t_position = grid_position(8, 28) }
    if direction == .South { t_position = grid_position(13, 30) }
    if direction == .North { t_position = grid_position(13, 29) }
    component_sprite.texture_position = t_position

    _mem.game.play.recompute_colliders = true
}

entity_create_heart :: proc(position: Vector2f32) -> Entity {
    entity := engine.entity_create_entity("Hearts")
    engine.entity_set_component(entity, engine.Component_Transform {
        position = position,
        scale = { 1, 1.5 },
    })
    component_sprite, component_sprite_err := engine.entity_set_component(entity, engine.Component_Sprite {
        texture_asset = _mem.game.asset_image_heart,
        texture_size = { 16, 24 },
        texture_position = { 0, 0 },
        texture_padding = TEXTURE_PADDING,
        z_index = i32(len(Level_Layers)) - i32(Level_Layers.Entities) + 1,
        tint = { 1, 1, 1, 1 },
        shader_asset = _mem.game.asset_shader_sprite,
    })
    idle_ase := new(Aseprite_Animation)
    idle_ase.frames["idle_0"] = { duration = 100, frame = { x = 16 * 0, y = 0, w = 16, h = 24 } }
    idle_ase.frames["idle_1"] = { duration = 100, frame = { x = 16 * 1, y = 0, w = 16, h = 24 } }
    idle_ase.frames["idle_2"] = { duration = 100, frame = { x = 16 * 2, y = 0, w = 16, h = 24 } }
    idle_ase.frames["idle_3"] = { duration = 100, frame = { x = 16 * 3, y = 0, w = 16, h = 24 } }
    idle_ase.frames["idle_4"] = { duration = 100, frame = { x = 16 * 4, y = 0, w = 16, h = 24 } }
    idle_ase.frames["idle_5"] = { duration = 100, frame = { x = 16 * 5, y = 0, w = 16, h = 24 } }
    idle_ase.frames["idle_6"] = { duration = 100, frame = { x = 16 * 6, y = 0, w = 16, h = 24 } }
    idle_ase.frames["idle_7"] = { duration = 100, frame = { x = 16 * 7, y = 0, w = 16, h = 24 } }
    idle_ase.frames["idle_8"] = { duration = 100, frame = { x = 16 * 8, y = 0, w = 16, h = 24 } }
    animation := make_aseprite_animation(idle_ase, &component_sprite.texture_position, loop = false, active = true)
    engine.animation_make_event(animation, 1, auto_cast(event_proc), Event_Data { entity })
    Event_Data :: struct {
        entity:      Entity,
    }
    event_proc :: proc(user_data: ^Event_Data) {
        engine.entity_delete_entity(user_data.entity)
    }

    return entity
}

entity_create_cloud :: proc(position: Vector2f32/* , duration: time.Duration */) -> Entity {
    entity := engine.entity_create_entity("Cloud")
    engine.entity_set_component(entity, engine.Component_Transform {
        position = position,
        scale = { 5, 4 },
    })
    component_sprite, component_sprite_err := engine.entity_set_component(entity, engine.Component_Sprite {
        texture_asset = _mem.game.asset_image_cloud,
        texture_size = { 80, 64 },
        texture_position = { 0, 0 },
        texture_padding = TEXTURE_PADDING,
        z_index = i32(len(Level_Layers)) - i32(Level_Layers.Entities) + 1,
        tint = { 1, 1, 1, 1 },
        shader_asset = _mem.game.asset_shader_sprite,
    })
    idle_ase := new(Aseprite_Animation)
    idle_ase.frames["idle_0"] = { duration = 100, frame = { x = 80 * 0, y = 0, w = 80, h = 64 } }
    idle_ase.frames["idle_1"] = { duration = 100, frame = { x = 80 * 1, y = 0, w = 80, h = 64 } }
    idle_ase.frames["idle_2"] = { duration = 100, frame = { x = 80 * 2, y = 0, w = 80, h = 64 } }
    idle_ase.frames["idle_3"] = { duration = 100, frame = { x = 80 * 3, y = 0, w = 80, h = 64 } }
    idle_ase.frames["idle_4"] = { duration = 100, frame = { x = 80 * 4, y = 0, w = 80, h = 64 } }
    animation := make_aseprite_animation(idle_ase, &component_sprite.texture_position, loop = true, active = true)
    engine.animation_make_event(animation, 1, auto_cast(event_proc), Event_Data { entity })
    Event_Data :: struct {
        entity:      Entity,
    }
    event_proc :: proc(user_data: ^Event_Data) {
        engine.entity_delete_entity(user_data.entity)
    }
    // engine.entity_set_component(entity, Component_Self_Destruct { time.time_add(time.now(), duration) })

    return entity
}

entity_create_mess :: proc(name: string, position: Vector2f32, variant : i32 = 0) -> Entity {
    entity := engine.entity_create_entity(name)
    engine.entity_set_component(entity, engine.Component_Transform {
        position = position,
        scale = { 1, 1 },
    })
    engine.entity_set_component(entity, Component_Collider {
        box = { position.x - GRID_SIZE / 2, position.y - GRID_SIZE / 2, GRID_SIZE, GRID_SIZE },
        type = { .Clean },
    })
    component_sprite, component_sprite_err := engine.entity_set_component(entity, engine.Component_Sprite {
        texture_asset = _mem.game.asset_image_tileset,
        texture_size = GRID_SIZE_V2,
        texture_position = grid_position(21 + variant, 7),
        texture_padding = TEXTURE_PADDING,
        tint = { 1, 1, 1, 1 },
        z_index = i32(len(Level_Layers)) - i32(Level_Layers.Entities) - 1,
        shader_asset = _mem.game.asset_shader_sprite,
    })
    component_messy, component_messy_err := engine.entity_set_component(entity, Component_Mess {})

    return entity
}

entity_create_torch :: proc(name: string, position: Vector2f32, lit: bool) -> Entity {
    size := Vector2f32 { 2, 2 }

    entity := engine.entity_create_entity(name)
    engine.entity_set_component(entity, engine.Component_Transform {
        position = position,
        scale = size,
    })
    component_sprite, component_sprite_err := engine.entity_set_component(entity, engine.Component_Sprite {
        texture_asset = _mem.game.asset_image_torch,
        texture_size = engine.vector_f32_to_i32(size * GRID_SIZE),
        // texture_position = texture_position,
        texture_padding = TEXTURE_PADDING,
        tint = { 1, 1, 1, 1 },
        z_index = i32(len(Level_Layers)) - i32(Level_Layers.Entities),
        shader_asset = _mem.game.asset_shader_sprite,
    })
    engine.entity_set_component(entity, Component_Collider {
        box = { position.x - size.x * GRID_SIZE / 2, position.y - size.y * GRID_SIZE / 2, size.x * GRID_SIZE, size.y * GRID_SIZE },
        type = { .Interact },
    })
    component_messy, component_messy_err := engine.entity_set_component(entity, Component_Interactive_Primary { type = .Repair_Torch })

    unlit_ase := new(Aseprite_Animation)
    unlit_ase.frames["unlit_0"] = { duration = 100, frame = { x = 32 * 0, y = 0, w = 32, h = 32 } }
    unlit_anim := make_aseprite_animation(unlit_ase, &component_sprite.texture_position, loop = true, active = false)

    lit_ase := new(Aseprite_Animation)
    lit_ase.frames["lit_0"] = { duration = 70, frame = { x = 32 * 1, y = 0, w = 32, h = 32 } }
    lit_ase.frames["lit_1"] = { duration = 70, frame = { x = 32 * 2, y = 0, w = 32, h = 32 } }
    lit_ase.frames["lit_2"] = { duration = 70, frame = { x = 32 * 3, y = 0, w = 32, h = 32 } }
    lit_ase.frames["lit_3"] = { duration = 70, frame = { x = 32 * 4, y = 0, w = 32, h = 32 } }
    lit_ase.frames["lit_4"] = { duration = 70, frame = { x = 32 * 5, y = 0, w = 32, h = 32 } }
    lit_ase.frames["lit_5"] = { duration = 70, frame = { x = 32 * 6, y = 0, w = 32, h = 32 } }
    lit_ase.frames["lit_6"] = { duration = 70, frame = { x = 32 * 7, y = 0, w = 32, h = 32 } }
    lit_ase.frames["lit_7"] = { duration = 70, frame = { x = 32 * 8, y = 0, w = 32, h = 32 } }
    lit_ase.frames["lit_8"] = { duration = 70, frame = { x = 32 * 9, y = 0, w = 32, h = 32 } }
    lit_anim := make_aseprite_animation(lit_ase, &component_sprite.texture_position, loop = true, active = false)
    engine.entity_set_component(entity, Component_Animator {
        animations = { "unlit" = unlit_anim, "lit" = lit_anim },
    })
    entity_change_animation(entity, lit ? "lit" : "unlit")

    return entity
}

entity_create_chest :: proc(name: string, position: Vector2f32) -> Entity {
    texture_position := grid_position(22, 4)
    size := Vector2f32 { 1, 2 }

    entity := engine.entity_create_entity(name)
    engine.entity_set_component(entity, engine.Component_Transform {
        position = position,
        scale = size,
    })
    engine.entity_set_component(entity, engine.Component_Sprite {
        texture_asset = _mem.game.asset_image_tileset,
        texture_size = engine.vector_f32_to_i32(size * GRID_SIZE),
        texture_position = texture_position,
        texture_padding = TEXTURE_PADDING,
        tint = { 1, 1, 1, 1 },
        z_index = i32(len(Level_Layers)) - i32(Level_Layers.Entities),
        shader_asset = _mem.game.asset_shader_sprite,
    })
    collider_size := Vector2f32 { 16, 8 }
    engine.entity_set_component(entity, Component_Collider {
        type   = { .Interact, .Block, .Target },
        box    = { position.x - collider_size.x / 2, position.y - collider_size.y / 2, collider_size.x, collider_size.y },
        offset = { 0, 8 },
    })
    engine.entity_set_component(entity, Component_Interactive_Primary { type = .Repair_Chest })
    engine.entity_set_component(entity, Component_Interactive_Secondary { type = .Carry })
    engine.entity_set_component(entity, Component_Interactive_Adventurer { type = .Loot })
    engine.entity_set_component(entity, Component_Loot { })

    return entity
}

entity_create_exit :: proc(name: string, position: Vector2f32, direction: Vector2i32) -> Entity {
    entity := engine.entity_create_entity(name)
    engine.entity_set_component(entity, engine.Component_Transform {
        position = position,
        scale = { 1, 1 },
    })
    collider_size := Vector2f32 { 16, 16 }
    engine.entity_set_component(entity, Component_Collider {
        type   = { .Exit },
        box    = { position.x - collider_size.x / 2, position.y - collider_size.y / 2, collider_size.x, collider_size.y },
    })
    engine.entity_set_component(entity, Component_Exit { direction = direction })

    return entity
}

box_center :: proc(box: Vector4f32) -> Vector2f32 {
    return {
        box.x + box.z / 2,
        box.y + box.w / 2,
    }
}

calculate_frame_velocity :: proc(velocity: Vector2f32) -> Vector2f32 {
    frame_stat := engine.get_frame_stat()
    time_scale := engine.get_time_scale()
    return velocity * frame_stat.delta_time * time_scale * 0.01
}
apply_velocity :: proc(position: ^Vector2f32, velocity: Vector2f32) {
    position^ += calculate_frame_velocity(velocity)
}

update_animator :: proc(entity: Entity, velocity: Vector2f32, animator: ^Component_Animator, horizontal_only := false) {
    normalized_velocity := linalg.normalize(velocity)
    if horizontal_only {
        if linalg.normalize(velocity).x > 0.1 {
            animator.direction = .East
        } else if linalg.normalize(velocity).x < 0.1 {
            animator.direction = .West
        }
    } else {
        octant := vector_to_octant(normalized_velocity)
        animator.direction = cast(Direction) octant
    }

    switch animator.direction {
        case .East: { entity_change_animation(entity, "walk_right" in animator.animations ? "walk_right" : "idle_right") }
        case .North: { entity_change_animation(entity, "walk_up" in animator.animations ? "walk_up" : "idle_up") }
        case .West: { entity_change_animation(entity, "walk_left" in animator.animations ? "walk_left" : "idle_left") }
        case .South: { entity_change_animation(entity, "walk_down" in animator.animations ? "walk_down" : "idle_down") }
    }
}

vector_to_octant :: proc(vector: Vector2f32, octant_count: i32 = 4) -> i32 {
    angle := math.atan2(vector.y, vector.x)
    octant := i32(math.round(f32(octant_count) * angle / (2 * math.PI) + f32(octant_count))) % octant_count
    return octant
}

direction_to_vector :: proc(direction: Direction) -> Vector2f32 {
    switch direction {
        case .East:  { return { +1, 0 } }
        case .North: { return { 0, -1 } }
        case .West:  { return { -1, 0 } }
        case .South: { return { 0, +1 } }
    }
    return { 0, 0 }
}

get_room_index_by_position :: proc(grid_position: Vector2i32) -> i32 {
    position_f32 := Vector2f32 {
        f32(grid_position.x) + 0.1, f32(grid_position.y) + 0.1,
    }
    for level, i in _mem.game.play.levels {
        level_box := Vector4f32 {
            f32(level.position.x),  f32(level.position.y),
            f32(level.size.x),      f32(level.size.y),
        }
        if engine.aabb_point_is_inside_box(position_f32, level_box) {
            return i32(i)
        }
    }
    return -1
}

refill_water :: proc(actor: Entity) {
    cleaner := engine.entity_get_component(actor, Component_Cleaner)
    cleaner.water_level = WATER_LEVEL_MAX
}

next_level :: proc() {
    _mem.game.current_level += 1
    game_mode_transition(.Game_Over)
}
