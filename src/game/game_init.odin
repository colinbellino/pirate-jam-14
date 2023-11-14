package game

import "core:log"
import "core:os"
import "core:slice"

import "../engine"

game_mode_init :: proc() {
    engine.renderer_set_palette(0, engine.renderer_make_palette({
        /*  0 */ { 0, 0, 0, 255 },
        /*  1 */ { 34, 32, 52, 255 },
        /*  2 */ { 69, 40, 60, 255 },
        /*  3 */ { 102, 57, 49, 255 },
        /*  4 */ { 143, 86, 59, 255 },
        /*  5 */ { 223, 113, 38, 255 },
        /*  6 */ { 217, 160, 102, 255 },
        /*  7 */ { 238, 195, 154, 255 },
        /*  8 */ { 251, 242, 54, 255 },
        /*  9 */ { 153, 229, 80, 255 },
        /* 10 */ { 106, 190, 48, 255 },
        /* 11 */ { 55, 148, 110, 255 },
        /* 12 */ { 75, 105, 47, 255 },
        /* 13 */ { 82, 75, 36, 255 },
        /* 14 */ { 50, 60, 57, 255 },
        /* 15 */ { 63, 63, 116, 255 },
        /* 16 */ { 48, 96, 130, 255 },
        /* 17 */ { 91, 110, 225, 255 },
        /* 18 */ { 99, 155, 255, 255 },
        /* 19 */ { 95, 205, 228, 255 },
        /* 20 */ { 203, 219, 252, 255 },
        /* 21 */ { 255, 255, 255, 255 },
        /* 22 */ { 155, 173, 183, 255 },
        /* 23 */ { 132, 126, 135, 255 },
        /* 24 */ { 105, 106, 106, 255 },
        /* 25 */ { 89, 86, 82, 255 },
        /* 26 */ { 118, 66, 138, 255 },
        /* 27 */ { 172, 50, 50, 255 },
        /* 28 */ { 217, 87, 99, 255 },
        /* 29 */ { 215, 123, 186, 255 },
        /* 30 */ { 143, 151, 74, 255 },
        /* 31 */ { 138, 111, 48, 255 },
    }))
    engine.renderer_set_palette(1, engine.renderer_make_palette({
        /*  0 */ { 0, 0, 0, 255 },
        /*  1 */ { 34, 32, 52, 255 },
        /*  2 */ { 69, 40, 60, 255 },
        /*  3 */ { 102, 57, 49, 255 },
        /*  4 */ { 143, 86, 59, 255 },
        /*  5 */ { 223, 113, 38, 255 },
        /*  6 */ { 217, 160, 102, 255 },
        /*  7 */ { 238, 195, 154, 255 },
        /*  8 */ { 251, 242, 54, 255 },
        /*  9 */ { 153, 229, 80, 255 },
        /* 10 */ { 106, 190, 48, 255 },
        /* 11 */ { 55, 148, 110, 255 },
        /* 12 */ { 75, 105, 47, 255 },
        /* 13 */ { 82, 75, 36, 255 },
        /* 14 */ { 50, 60, 57, 255 },
        /* 15 */ { 55, 148, 110, 255 },
        /* 16 */ { 48, 96, 130, 255 },
        /* 17 */ { 106, 190, 48, 255 },
        /* 18 */ { 99, 155, 255, 255 },
        /* 19 */ { 95, 205, 228, 255 },
        /* 20 */ { 203, 219, 252, 255 },
        /* 21 */ { 255, 255, 255, 255 },
        /* 22 */ { 155, 173, 183, 255 },
        /* 23 */ { 132, 126, 135, 255 },
        /* 24 */ { 105, 106, 106, 255 },
        /* 25 */ { 89, 86, 82, 255 },
        /* 26 */ { 118, 66, 138, 255 },
        /* 27 */ { 172, 50, 50, 255 },
        /* 28 */ { 217, 87, 99, 255 },
        /* 29 */ { 215, 123, 186, 255 },
        /* 30 */ { 143, 151, 74, 255 },
        /* 31 */ { 138, 111, 48, 255 },
    }))

    _game.asset_image_debug = 3
    _game.debug_draw_tiles = true
    _game.debug_draw_entities = true
    _game.debug_render_z_index_0 = true
    _game.debug_render_z_index_1 = true

    _game.debug_ui_entity_units = true
    _game.debug_ui_window_game = true

    _game.units = [dynamic]Unit {
        Unit { name = "Ramza", sprite_position = { 0, 0 }, stat_health = 10, stat_health_max = 10, stat_speed = 5, stat_move = 5 },
        Unit { name = "Delita", sprite_position = { 3, 1 }, stat_health = 20, stat_health_max = 20, stat_speed = 3, stat_move = 5 },
        Unit { name = "Alma", sprite_position = { 2, 1 }, stat_health = 30, stat_health_max = 30, stat_speed = 6, stat_move = 5 },
        Unit { name = "Wiegraf", sprite_position = { 1, 1 }, stat_health = 10, stat_health_max = 10, stat_speed = 8, stat_move = 5 },
        Unit { name = "Belias", sprite_position = { 0, 0 }, stat_health = 20, stat_health_max = 20, stat_speed = 5, stat_move = 5 },
        Unit { name = "Gaffgarion", sprite_position = { 1, 1 }, stat_health = 30, stat_health_max = 30, stat_speed = 4, stat_move = 5 },
    }
    _game.party = { 0, 1, 2 }
    _game.foes = { 3, 4, 5 }

    // TODO: generate the asset list in the build process
    _game.asset_map_world           = engine.asset_add("media/levels/worldmap.ldtk", .Map)
    _game.asset_map_areas           = engine.asset_add("media/levels/areas.ldtk", .Map)
    _game.asset_image_spritesheet   = engine.asset_add("media/art/spritesheet.png", .Image)
    _game.asset_image_units         = engine.asset_add("media/art/units.png", .Image)
    _game.asset_image_battle_bg     = engine.asset_add("media/art/battle_background_xl.png", .Image)
    _game.asset_shader_sprite       = engine.asset_add("media/shaders/shader_aa_sprite.glsl", .Shader)
    _game.asset_shader_sprite_aa    = engine.asset_add("media/shaders/shader_sprite.glsl", .Shader)
    _game.asset_shader_test         = engine.asset_add("media/shaders/shader_test.glsl", .Shader)
    _game.asset_shader_line         = engine.asset_add("media/shaders/shader_line.glsl", .Shader)
    _game.asset_image_nyan          = engine.asset_add("media/art/nyan.png", .Image)
    _game.asset_music_worldmap      = engine.asset_add("media/audio/musics/8-bit (4).ogg", .Audio)
    _game.asset_music_battle        = engine.asset_add("media/audio/musics/8-bit (6).ogg", .Audio)
    _game.asset_sound_cancel        = engine.asset_add("media/audio/sounds/cancel.mp3", .Audio)
    _game.asset_sound_confirm       = engine.asset_add("media/audio/sounds/confirm.mp3", .Audio)
    _game.asset_sound_invalid       = engine.asset_add("media/audio/sounds/invalid.mp3", .Audio)
    _game.asset_sound_hit           = engine.asset_add("media/audio/sounds/hit.mp3", .Audio)

    engine.asset_load(_game.asset_shader_sprite)
    engine.asset_load(_game.asset_shader_line)

    engine.asset_load(_game.asset_image_nyan, engine.Image_Load_Options { filter = engine.RENDERER_FILTER_NEAREST })
    engine.asset_load(_game.asset_image_units, engine.Image_Load_Options { engine.RENDERER_FILTER_NEAREST, engine.RENDERER_CLAMP_TO_EDGE })

    engine.asset_load(_game.asset_sound_cancel)
    engine.asset_load(_game.asset_sound_confirm)
    engine.asset_load(_game.asset_sound_invalid)
    engine.asset_load(_game.asset_sound_hit)

    engine.renderer_update_viewport()
    _engine.renderer.ui_camera.zoom = _engine.renderer.ideal_scale
    _engine.renderer.world_camera.zoom = _engine.renderer.ideal_scale
    _engine.renderer.draw_ui = true

    engine.audio_set_volume_main(GAME_VOLUME_MAIN)
    engine.audio_set_volume_music(0.0)
    engine.audio_set_volume_sound(1.0)

    // _engine.time_scale = 1_000

    game_mode_transition(.Title)
}
