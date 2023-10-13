package game

import "core:log"
import "../engine"

// TODO: move this to engine
animation_update :: proc() {
    animations := engine.animation_get_all_animations()
    for _, i in animations {
        animation := animations[i]

        for curve in animation.curves {
            switch curve in curve {
                case engine.Animation_Curve_Position: {
                    component_transform, has_transform := &_game.entities.components_transform[curve.entity]
                    if has_transform {
                        position := engine.animation_lerp_value_curve(curve, animation.t)
                        component_transform.position = position
                    }
                }
                case engine.Animation_Curve_Scale: {
                    component_transform, has_transform := &_game.entities.components_transform[curve.entity]
                    if has_transform {
                        scale := engine.animation_lerp_value_curve(curve, animation.t)
                        component_transform.scale = scale
                    }
                }
                case engine.Animation_Curve_Color: {
                    component_rendering, has_rendering := &_game.entities.components_rendering[curve.entity]
                    if has_rendering {
                        color := engine.animation_lerp_value_curve(curve, animation.t)
                        component_rendering.color = transmute(Color) color
                    }
                }
                case engine.Animation_Curve_Sprite: {
                    component_rendering, has_rendering := &_game.entities.components_rendering[curve.entity]
                    if has_rendering {
                        sprite_index := engine.animation_lerp_value_curve(curve, animation.t)
                        texture_position := engine.grid_index_to_position(int(sprite_index), 7) * component_rendering.texture_size
                        component_rendering.texture_position = texture_position
                    }
                }
            }
        }

        animation.t += _engine.platform.delta_time / 1000 * animation.speed
        if animation.t > 1 {
            if animation.loop {
                animation.t = 0
            } else {
                animation.t = 1
            }
        }
    }
}
