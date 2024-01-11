package engine

import "core:container/queue"
import "core:fmt"
import "core:log"
import "core:math"
import "core:math/ease"
import "core:mem"
import "core:strings"
import "../tools"

Animation_State :: struct {
    arena:         tools.Named_Virtual_Arena,
    animations:    [ANIMATION_ANIMATIONS_COUNT]Animation,
    queues:        [ANIMATION_QUEUES_COUNT]queue.Queue(^Animation),
}

Animation :: struct {
    active:     bool,
    t:          f32,
    loop:       bool,
    parallel:   bool,
    speed:      f32,
    curves:     [dynamic]Animation_Curve,
    procedure:  proc(animation: ^Animation) -> f32,
    user_data:  rawptr,
}

Animation_Curve :: union {
    Animation_Curve_Position,
    Animation_Curve_Scale,
    Animation_Curve_Color,
    Animation_Curve_Sprite,
    Animation_Curve_Event,
}

Animation_Curve_Base :: struct($Data: typeid) {
    target:     ^Data,
    timestamps: [dynamic]f32,
    frames:     [dynamic]Data,
}
Animation_Curve_Position :: distinct Animation_Curve_Base(Vector2f32)
Animation_Curve_Scale    :: distinct Animation_Curve_Base(Vector2f32)
Animation_Curve_Color    :: distinct Animation_Curve_Base(Vector4f32)
Animation_Curve_Sprite   :: distinct Animation_Curve_Base(i8)
Animation_Curve_Event    :: distinct Animation_Curve_Base(Curve_Event)

Curve_Event :: struct {
    procedure: proc(user_data: rawptr),
    sent:      bool,
    user_data: rawptr,
}

ANIMATION_ANIMATIONS_COUNT :: 100
ANIMATION_QUEUES_COUNT     :: 10
ANIMATION_ARENA_SIZE       :: mem.Megabyte

@(private="file")
_animation: ^Animation_State

animation_init :: proc() -> (animation_state: ^Animation_State, ok: bool) #optional_ok {
    _animation = tools.mem_named_arena_virtual_bootstrap_new_or_panic(Animation_State, "arena", ANIMATION_ARENA_SIZE, "animation")
    for i := 0; i < ANIMATION_QUEUES_COUNT; i += 1 {
        queue.init(&_animation.queues[i], allocator = _animation.arena.allocator)
    }

    animation_state = _animation
    ok = true
    return
}

animation_reload :: proc(animation_state: ^Animation_State) {
    assert(animation_state != nil)
    _animation = animation_state
}

animation_create_animation :: proc(speed: f32 = 1.0, allocator := context.allocator) -> ^Animation {
    context.allocator = allocator
    assert(speed > 0, "animation speed can't be <= 0")

    available_index := animation_get_available_index()
    assert(available_index >= 0, "no animation slot available")
    assert(available_index < ANIMATION_ANIMATIONS_COUNT, "max animation reached")

    animation := &_animation.animations[available_index]
    animation.speed = speed
    return animation
}

animation_get_available_index :: proc() -> int {
    available_index := -1
    for animation, i in _animation.animations {
        if animation.speed == 0 {
            available_index = i
            break
        }
    }
    return available_index
}

animation_is_done :: proc(animation: ^Animation) -> bool {
    return animation.t >= 1
}

animation_add_curve :: proc(animation: ^Animation, curve: Animation_Curve) {
    append(&animation.curves, curve)
}

animation_lerp_value_curve :: proc(curve: Animation_Curve_Base($T), t: f32, loc := #caller_location) -> T {
    assert(len(curve.frames) > 0, "frames length > 0", loc)
    assert(len(curve.timestamps) > 0, "timestamps length > 0", loc)
    assert(len(curve.frames) == len(curve.timestamps), "frames length == timestamps length", loc)

    step_current := 0
    for timestamp, i in curve.timestamps {
        if t > timestamp {
            step_current = i
        }
    }

    step_next := math.min(step_current + 1, len(curve.timestamps) - 1)
    step_duration := curve.timestamps[step_next] - curve.timestamps[step_current]
    step_progress := ease.ease(.Linear, (t - curve.timestamps[step_current]) / step_duration)

    when T == i8 {
        return i8(math.lerp(f32(curve.frames[step_current]), f32(curve.frames[step_next]), step_progress))
    } else {
        return math.lerp(curve.frames[step_current], curve.frames[step_next], step_progress)
    }
}

animation_delete_animation :: proc(animation: ^Animation) {
    animation^ = {}
    // FIXME: delete curves?
}

animation_update :: proc() {
    profiler_zone("animation_update")
    frame_stat := get_frame_stat()
    tick := frame_stat.delta_time / 1000 * _core.time_scale
    count := math.max(1, int(_core.time_scale))

    for i := 0; i < count; i += 1 {
        for _, i in _animation.animations {
            animation := &_animation.animations[i]

            if animation.active == false {
                continue
            }

            if animation.procedure != nil {
                animation.t = animation.procedure(animation)
            } else {
                animation.t += tick * animation.speed
                if animation.t > 1 {
                    if animation.loop {
                        animation.t = 0
                    } else {
                        animation.t = 1
                    }
                }
            }

            for curve in animation.curves {
                switch curve in curve {
                    case Animation_Curve_Position: {
                        curve.target^ = animation_lerp_value_curve(curve, animation.t)
                    }
                    case Animation_Curve_Scale: {
                        curve.target^ = animation_lerp_value_curve(curve, animation.t)
                    }
                    case Animation_Curve_Color: {
                        curve.target^ = animation_lerp_value_curve(curve, animation.t)
                    }
                    case Animation_Curve_Sprite: {
                        // FIXME: Not sure how to handle this because we need a pointer to the Component_Sprite but right now the components are part of the game, not the
                        // sprite_index := animation_lerp_value_curve(curve, animation.t)
                        // texture_position := grid_index_to_position(int(sprite_index), 7) * component_rendering.texture_size
                        // curve.target^ = texture_position
                    }
                    case Animation_Curve_Event: {
                        for timestamp, i in curve.timestamps {
                            event := &curve.frames[i]
                            if animation.t >= timestamp && event.sent == false {
                                event.procedure(event.user_data)
                                if event.user_data != nil {
                                    free(event.user_data)
                                }
                                event.sent = true
                            }
                        }
                    }
                }
            }
        }

        for _, animation_index in _animation.queues {
            animations := &_animation.queues[animation_index]

            if queue.len(animations^) == 0 {
                break
            }

            current_animation := queue.peek_front(animations)^
            if current_animation == nil {
                log.warnf("Empty animation queue.")
                break
            }
            if current_animation.active == false {
                current_animation.active = true
            }
            if animation_is_done(current_animation) {
                animation_delete_animation(current_animation)
                queue.pop_front(animations)
            }
            if current_animation.parallel {
                queue.pop_front(animations)
                queue.push_back(animations, current_animation)
            }
        }
    }
}

animation_queue_is_done :: proc(animation_queue: ^queue.Queue(^Animation)) -> bool {
    return queue.len(animation_queue^) == 0
}

// TODO: return id of queue instead of pointer
animation_make_queue :: proc() -> (^queue.Queue(^Animation), bool) {
    for animation_queue, i in _animation.queues {
        if queue.len(animation_queue) == 0 {
            return &_animation.queues[i], true
        }
    }
    return nil, false
}

animation_make_event :: proc {
    animation_make_event_no_user_data,
    animation_make_event_user_data,
}
animation_make_event_no_user_data :: proc(animation: ^Animation, timestamp: f32, event_proc: proc(user_data: rawptr), allocator := context.allocator) {
    context.allocator = allocator
    animation_add_curve(animation, Animation_Curve_Event {
        timestamps = { timestamp },
        frames = { { procedure = event_proc } },
    })
}
animation_make_event_user_data :: proc(animation: ^Animation, timestamp: f32, event_proc: proc(user_data: rawptr), user_data: $type, allocator := context.allocator) {
    context.allocator = allocator
    user_data_clone := new(type)
    user_data_clone^ = user_data
    animation_add_curve(animation, Animation_Curve_Event {
        timestamps = { timestamp },
        frames = { { procedure = event_proc, user_data = user_data_clone } },
    })
}

ui_window_animation :: proc(open: ^bool) {
    if open^ {
        if ui_window("Animations", open) {
            if ui_collapsing_header("Animations", { .DefaultOpen }) {
                ui_text("Animations (%v/%v)", animation_get_available_index(), len(_animation.animations))

                if len(_animation.animations) == 0 {
                    ui_text("No animation.")
                } else {
                    for animation, i in _animation.animations {
                        if ui_tree_node(fmt.tprintf("animation %v | %p", i, &_animation.animations[i]), { .DefaultOpen }) {
                            ui_checkbox("active", &_animation.animations[i].active)
                            ui_same_line()
                            ui_checkbox("loop", &_animation.animations[i].loop)
                            ui_same_line()
                            ui_push_item_width(50)
                            ui_input_float("speed", &_animation.animations[i].speed)
                            ui_same_line()
                            ui_slider_float("t", &_animation.animations[i].t, 0, 1)

                            if ui_tree_node("Curves", { .DefaultOpen }) {
                                for curve in animation.curves {
                                    ui_text("curve: %v", curve)
                                    #partial switch curve in curve {
                                        case Animation_Curve_Position: {
                                            ui_text("target:     %p %v", curve.target, curve.target)
                                            ui_text("frames:     %v", curve.frames)
                                            ui_text("timestamps: %v", curve.timestamps)
                                        }
                                        case: {
                                            ui_text("???")
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            if ui_collapsing_header("Queues") {
                columns := []string { "index", "len", "details" }
                if ui_table(columns) {
                    for _, animation_index in _animation.queues {
                        ui_table_next_row()

                        animation_queue := &_animation.queues[animation_index]
                        for column, i in columns {
                            ui_table_set_column_index(i32(i))
                            switch column {
                                case "index": ui_text(fmt.tprintf("%v", i))
                                case "len": ui_text(fmt.tprintf("%v", queue.len(animation_queue^)))
                                case "details": {
                                    parts := make([dynamic]string, context.temp_allocator)
                                    for i := 0; i < queue.len(animation_queue^); i += 1 {
                                        animation := queue.get(animation_queue, i)
                                        append(&parts, fmt.tprintf("%p", animation))
                                        if i < queue.len(animation_queue^) - 1 {
                                            append(&parts, ", ")
                                        }
                                    }
                                    str := strings.concatenate(parts[:], context.temp_allocator)
                                    ui_text(str)
                                }
                                case: ui_text("x")
                            }
                        }
                    }
                }
            }
        }
    }
}

/////////////////////////////////////

/*
Usage example:
```
animations_f32 := []Animation_Step(f32) {
    { 0.0, 0.0, .Linear },
    { 0.5, 0.5, .Linear },
    { 1.0, 1.0, .Linear },
}
animations_color := []Animation_Step(Color) {
    { 0.0, { 0.0, 0.0, 1.0, 1 }, .Linear },
    { 0.5, { 0.0, 1.0, 0.5, 1 }, .Linear },
    { 1.0, { 1.0, 1.0, 1.0, 1 }, .Linear },
}
```
*/
Animation_Step :: struct($Value: typeid) {
    t:     f32,
    ease:  ease.Ease,
    value: Value,
}

animation_lerp_value :: proc(animation: []Animation_Step($T), t: f32, loc := #caller_location) -> T {
    assert(len(animation) > 1, "animation length > 1", loc)
    assert(animation[0].t == 0, "animation[first].t == 0", loc)
    assert(animation[len(animation) - 1].t == 1, "animation[last].t == 1", loc)

    step := 0
    for animation, i in animation {
        if t > animation.t {
            step = i
        }
    }

    step_next := math.min(step + 1, len(animation) - 1)
    step_duration := animation[step_next].t - animation[step].t
    step_progress := ease.ease(animation[step].ease, (t - animation[step].t) / step_duration)

    when T == i8 {
        return i8(math.lerp(f32(animation[step].value), f32(animation[step_next].value), step_progress))
    } else {
        return math.lerp(animation[step].value, animation[step_next].value, step_progress)
    }
}

ui_animation_plot :: proc(label: string, animation: []Animation_Step($T), count := 100) {
    context.allocator = context.temp_allocator

    values := make([]T, count)
    for _, i in values {
        values[i] = animation_lerp_value(animation, f32(i) / f32(len(values)))
    }

    when T == f32 {
        ui_plot_lines_float_ptr(label, &values[0], i32(len(values)), 0, "", slice.min(values), slice.max(values), { 500, 80 })
    }
    else when T == i32 {
        ui_plot_lines_fn_float_ptr(label, getter_i32, &values, i32(len(values)), 0, "", f32(slice.min(values)), f32(slice.max(values)), { 500, 20 })
        getter_i32 :: proc "c" (data: rawptr, idx: i32) -> f32 { return f32((cast(^[]i32) data)[idx]) }
    }
    else when T == Vector4f32 {
        ui_plot_lines_fn_float_ptr(strings.clone_to_cstring(strings.concatenate({ label, "_0" })), getter_vector4f32_0, &values, i32(len(values)), 0, "", 0, 1, { 500, 20 })
        ui_plot_lines_fn_float_ptr(strings.clone_to_cstring(strings.concatenate({ label, "_1" })), getter_vector4f32_1, &values, i32(len(values)), 0, "", 0, 1, { 500, 20 })
        ui_plot_lines_fn_float_ptr(strings.clone_to_cstring(strings.concatenate({ label, "_2" })), getter_vector4f32_2, &values, i32(len(values)), 0, "", 0, 1, { 500, 20 })
        ui_plot_lines_fn_float_ptr(strings.clone_to_cstring(strings.concatenate({ label, "_3" })), getter_vector4f32_3, &values, i32(len(values)), 0, "", 0, 1, { 500, 20 })
        getter_vector4f32_0 :: proc "c" (data: rawptr, idx: i32) -> f32 { return (cast(^[]Vector4f32) data)[idx][0] }
        getter_vector4f32_1 :: proc "c" (data: rawptr, idx: i32) -> f32 { return (cast(^[]Vector4f32) data)[idx][1] }
        getter_vector4f32_2 :: proc "c" (data: rawptr, idx: i32) -> f32 { return (cast(^[]Vector4f32) data)[idx][2] }
        getter_vector4f32_3 :: proc "c" (data: rawptr, idx: i32) -> f32 { return (cast(^[]Vector4f32) data)[idx][3] }
    }
    else {
        ui_text("ui_animation_plot: type not supported (%v)", typeid_of(T))
        return
    }
}
