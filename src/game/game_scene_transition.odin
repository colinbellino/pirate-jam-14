package game

import "core:time"
import "core:math"
import "../engine"

Scene_Transition :: struct {
    ends_at:    time.Time,
    duration:   time.Duration,
    type:       Scene_Transition_Types,
}

Scene_Transition_Types :: enum { Swipe_Left_To_Right, Unswipe_Left_To_Right }

scene_transition_start :: proc(type: Scene_Transition_Types, duration: time.Duration = time.Millisecond * 500, location := #caller_location) {
    assert(duration > 0)
    _mem.game.scene_transition.type = type
    _mem.game.scene_transition.duration = time.Duration(f32(duration) / engine.get_time_scale())
    _mem.game.scene_transition.ends_at = time.time_add(time.now(), _mem.game.scene_transition.duration)
    // log.debugf("start transition %v -> %v", _mem.game.scene_transition.ends_at, location)
}

scene_transition_is_done :: proc() -> bool {
    now := time.now()
    result := now._nsec > _mem.game.scene_transition.ends_at._nsec
    return result
}

scene_transition_calculate_progress :: proc() -> f32 {
    start := _mem.game.scene_transition.ends_at._nsec - i64(_mem.game.scene_transition.duration)
    now := time.now()._nsec
    duration := _mem.game.scene_transition.duration
    return math.clamp(f32(now - start) / f32(duration), 0, 1)
}
