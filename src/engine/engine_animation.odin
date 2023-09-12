package engine

import "core:math"
import "core:math/ease"

/*
animations_f32 := []Animation(f32) {
    { 0.0, 0.0, .Linear },
    { 0.5, 0.5, .Linear },
    { 1.0, 1.0, .Linear },
}
animations_color := []Animation(Color) {
    { 0.0, { 0.0, 0.0, 1.0, 1 }, .Linear },
    { 0.5, { 0.0, 1.0, 0.5, 1 }, .Linear },
    { 1.0, { 1.0, 1.0, 1.0, 1 }, .Linear },
}
*/
Animation :: struct($Value: typeid) {
    t:     f32,
    value: Value,
    ease:  ease.Ease,
}

animation_lerp_value :: proc(animations: []Animation($T), t: f32) -> T {
    assert(len(animations) > 1)
    assert(animations[0].t == 0)
    assert(animations[len(animations) - 1].t == 1)

    step := 0
    for animation, i in animations {
        if t > animation.t {
            step = i
        }
    }

    step_next := math.min(step + 1, len(animations) - 1)
    step_duration := animations[step_next].t - animations[step].t
    step_progress := ease.ease(animations[step].ease, (t - animations[step].t) / step_duration)

    // engine.ui_text("step: %i %v", step, animations[step])
    // engine.ui_text("next: %i %v", step_next, animations[step_next])
    // engine.ui_text("step_duration: %v", step_duration)
    // engine.ui_slider_float("step_progress", &step_progress, 0, 1)

    return math.lerp(animations[step].value, animations[step_next].value, step_progress)
}
