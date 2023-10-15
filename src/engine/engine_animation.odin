package engine

import "core:math"
import "core:math/ease"
import "core:slice"
import "core:strings"
import "core:fmt"
import "core:log"
import "core:container/queue"

Animation_Player :: struct {
    animations: [dynamic]^Animation,
}

Animation :: struct {
    active: bool,
    t:      f32,
    loop:   bool,
    speed:  f32,
    curves: [dynamic]Animation_Curve,
}

Animation_Curve :: union {
    Animation_Curve_Position,
    Animation_Curve_Scale,
    Animation_Curve_Color,
    Animation_Curve_Sprite,
}

Animation_Curve_Base :: struct($Frame: typeid) {
    entity:     Entity,
    timestamps: [dynamic]f32,
    frames:     [dynamic]Frame,
}
Animation_Curve_Position :: distinct Animation_Curve_Base(Vector2f32)
Animation_Curve_Scale    :: distinct Animation_Curve_Base(Vector2f32)
Animation_Curve_Color    :: distinct Animation_Curve_Base(Vector4f32)
Animation_Curve_Sprite   :: distinct Animation_Curve_Base(i8)

animation_get_all_animations :: proc() -> [dynamic]^Animation {
    return _e.animation_player.animations
}

animation_is_done :: proc(animation: ^Animation) -> bool {
    return animation.t >= 1
}

animation_create_animation :: proc(speed: f32 = 1.0) -> ^Animation {
    context.allocator = _e.allocator
    animation := new(Animation)
    animation.speed = speed
    append(&_e.animation_player.animations, animation)
    return animation
}

animation_add_curve :: proc(animation: ^Animation, curve: Animation_Curve) {
    context.allocator = _e.allocator
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

    // ui_text("current:    %i %v", step_current, curve.frames[step_current])
    // ui_text("next:       %i %v", step_next, curve.frames[step_next])
    // ui_text("step_duration: %v", step_duration)
    // ui_slider_float("step_progress", &step_progress, 0, 1)

    when T == i8 {
        return i8(math.lerp(f32(curve.frames[step_current]), f32(curve.frames[step_next]), step_progress))
    } else {
        return math.lerp(curve.frames[step_current], curve.frames[step_next], step_progress)
    }
}

animation_advance_queue :: proc(animations: ^queue.Queue(^Animation)) -> (done: bool) {
    current_animation := queue.peek_front(animations)^
    if current_animation == nil {
        log.warnf("Empty animation queue.")
        return true
    }
    if current_animation.active == false {
        current_animation.active = true
    }
    if animation_is_done(current_animation) {
        animation_delete_animation(current_animation)
        queue.pop_front(animations)
    }
    done = queue.len(animations^) == 0
    return done
}

animation_delete_animation :: proc(animation: ^Animation) {
    for current_animation, i in _e.animation_player.animations {
        if current_animation == animation {
            ordered_remove(&_e.animation_player.animations, i)
        }
    }
}

ui_debug_window_animation :: proc(open: ^bool) {
    if open^ {
        if ui_window("Animations: Engine", open) {
            if len(_e.animation_player.animations) == 0 {
                ui_text("No animation.")
            } else {
                for animation, i in _e.animation_player.animations {
                    if ui_tree_node(fmt.tprintf("animation %v", i), { .DefaultOpen }) {
                        ui_checkbox("active", &animation.active)
                        ui_same_line()
                        ui_checkbox("loop", &animation.loop)
                        ui_same_line()
                        ui_push_item_width(100)
                        ui_input_float("speed", &animation.speed)
                        ui_same_line()
                        ui_slider_float("t", &animation.t, 0, 1)

                        if ui_tree_node("Curves", {}) {
                            for curve in animation.curves {
                                #partial switch curve in curve {
                                    case Animation_Curve_Position: {
                                        ui_text("entity: %v", curve.entity)
                                        ui_text("%#v", curve.frames)
                                    }
                                }
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

    // ui_text("step: %i %v", step, animation[step])
    // ui_text("next: %i %v", step_next, animation[step_next])
    // ui_text("step_duration: %v", step_duration)
    // ui_slider_float("step_progress", &step_progress, 0, 1)

    when T == i8 {
        return i8(math.lerp(f32(animation[step].value), f32(animation[step_next].value), step_progress))
    } else {
        return math.lerp(animation[step].value, animation[step_next].value, step_progress)
    }
}

// FIXME: this is extremely wasteful
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
