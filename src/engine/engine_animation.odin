package engine

import "core:math"
import "core:math/ease"
import "core:slice"
import "core:strings"

/*
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
*/
Animation_Step :: struct($Value: typeid) {
    t:     f32,
    value: Value,
    ease:  ease.Ease,
}

animation_lerp_value :: proc(animation: []Animation_Step($T), t: f32) -> T {
    assert(len(animation) > 1)
    assert(animation[0].t == 0)
    assert(animation[len(animation) - 1].t == 1)

    step := 0
    for animation, i in animation {
        if t > animation.t {
            step = i
        }
    }

    step_next := math.min(step + 1, len(animation) - 1)
    step_duration := animation[step_next].t - animation[step].t
    step_progress := ease.ease(animation[step].ease, (t - animation[step].t) / step_duration)

    // engine.ui_text("step: %i %v", step, animation[step])
    // engine.ui_text("next: %i %v", step_next, animation[step_next])
    // engine.ui_text("step_duration: %v", step_duration)
    // engine.ui_slider_float("step_progress", &step_progress, 0, 1)

    when T == i32 {
        return i32(math.lerp(f32(animation[step].value), f32(animation[step_next].value), step_progress))
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
        ui_plot_lines_fn_float_ptr(strings.concatenate({ label, "_0" }, context.temp_allocator), getter_vector4f32_0, &values, i32(len(values)), 0, "", 0, 1, { 500, 20 })
        ui_plot_lines_fn_float_ptr(strings.concatenate({ label, "_1" }, context.temp_allocator), getter_vector4f32_1, &values, i32(len(values)), 0, "", 0, 1, { 500, 20 })
        ui_plot_lines_fn_float_ptr(strings.concatenate({ label, "_2" }, context.temp_allocator), getter_vector4f32_2, &values, i32(len(values)), 0, "", 0, 1, { 500, 20 })
        ui_plot_lines_fn_float_ptr(strings.concatenate({ label, "_3" }, context.temp_allocator), getter_vector4f32_3, &values, i32(len(values)), 0, "", 0, 1, { 500, 20 })
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
