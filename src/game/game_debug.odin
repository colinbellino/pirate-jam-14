package game

import "core:log"

import "../engine"

Component_Key_Frame :: struct {
    frames_scale:      [dynamic]Key_Frame,
}

Key_Frame :: struct {
    t:          f64,
    scale:      Vector2f32,
}

// bla_entity: Entity
// bla_key_frame: Component_Key_Frame
// bla_t: f64

game_mode_update_debug_scene :: proc() {
    if game_mode_enter() {
        // context.allocator = game.game_mode_allocator

        // entity := entity_make("Debug Unit")
        // entity_add_transform(entity, { 8, 8 })
        // entity_add_sprite(entity, game.asset_tilemap, { 0, 112 }, { 8, 8 })

        // component_key_frame = Component_Key_Frame { }
        // // component_key_frame.frames_scale = []Key_Frame { }
        // append(&component_key_frame.frames_scale, Key_Frame { 0, { +1, 0 } })
        // append(&component_key_frame.frames_scale, Key_Frame { 1, { -1, 0 } })

        // bla_entity = entity
    }

    if engine.ui_window("Animations", { 600, 400, 400, 400 }, { .NO_CLOSE }) {
        if .ACTIVE in engine.ui_header("Unit", { .EXPANDED }) {
            engine.ui_layout_row({ 100, -1 }, 0)

            engine.ui_label("Idle")
            if .SUBMIT in engine.ui_button("Play") {
                log.debug("idle")
            }
            engine.ui_label("Walk")
            if .SUBMIT in engine.ui_button("Play") {
                log.debug("walk")
            }
            engine.ui_label("Rotate")
            if .SUBMIT in engine.ui_button("Play") {
                log.debug("rotate")
            }
        }
    }

    // {
    //     entity := bla_entity
    //     bla_t := delta_time
    //     // TODO: lerp between frames: 1.0 -> 0.5 -> 0.0 -> -0.5 -> -1.0,
    // }
}
