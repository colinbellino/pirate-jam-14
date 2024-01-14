package game

import "core:fmt"
import "core:log"
import "core:slice"
import "core:sort"
import "core:strings"
import "../engine"

Aseprite_Animation :: struct {
    frames:             map[string]Aseprite_Frame,
}
Aseprite_Frame :: struct {
    frame:              struct { x, y, w, h: i32 },
    rotated:            bool,
    trimmed:            bool,
    spriteSourceSize:   struct { x, y: i32 },
    sourceSize:         struct { x, y: i32 },
    duration:           i32,
}

make_aseprite_animation :: proc(anim: ^Aseprite_Animation, target: ^Vector2i32) -> ^engine.Animation {
    frames := make([dynamic]Vector2i32, len(anim.frames))
    timestamps := make([dynamic]f32, len(anim.frames))

    keys, keys_err := slice.map_keys(anim.frames, context.temp_allocator)
    assert(keys_err == .None)
    sort_keys :: proc(a, b: string) -> int {
        return strings.compare(a, b)
    }
    sort.quick_sort_proc(keys, sort_keys)

    duration_s := f32(0)
    for key in keys {
        frame := anim.frames[key]
        duration_s += f32(frame.duration) / 1_000
    }
    step := 1 / duration_s

    i := i32(0)
    for key in keys {
        frame := anim.frames[key]
        timestamps[i] = (f32(frame.duration) / 1_000) * f32(i) * step
        frames[i] = { frame.frame.x, frame.frame.y }
        i += 1
    }

    animation := engine.animation_create_animation(1)
    animation.loop = true
    animation.active = true
    engine.animation_add_curve(animation, engine.Animation_Curve_Sprite {
        target = target,
        timestamps = timestamps,
        frames = frames,
    })

    return animation
}
