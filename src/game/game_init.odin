package game

import "core:log"

import "../engine"

game_mode_init :: proc() {
    test := engine.entity_create_entity("test")

    // TODO: generate the asset list in the build process
    _game.asset_worldmap            = engine.asset_add("media/levels/worldmap.ldtk", .Map)
    _game.asset_areas               = engine.asset_add("media/levels/areas.ldtk", .Map)
    _game.asset_tilemap             = engine.asset_add("media/art/spritesheet.png", .Image)
    _game.asset_battle_background   = engine.asset_add("media/art/battle_background_xl.png", .Image)
    _game.asset_shader_sprite       = engine.asset_add("media/shaders/shader_aa_sprite.glsl", .Shader)
    _game.asset_shader_sprite_aa    = engine.asset_add("media/shaders/shader_sprite.glsl", .Shader)
    _game.asset_nyan                = engine.asset_add("media/art/nyan.png", .Image)
    _game.asset_music_worldmap      = engine.asset_add("media/audio/musics/8-bit (4).ogg", .Audio)
    _game.asset_music_battle        = engine.asset_add("media/audio/musics/8-bit (6).ogg", .Audio)
    _game.asset_sound_cancel        = engine.asset_add("media/audio/sounds/cancel.mp3", .Audio)
    _game.asset_sound_confirm       = engine.asset_add("media/audio/sounds/confirm.mp3", .Audio)
    _game.asset_sound_invalid       = engine.asset_add("media/audio/sounds/invalid.mp3", .Audio)
    _game.asset_sound_hit           = engine.asset_add("media/audio/sounds/hit.mp3", .Audio)

    _game.draw_hud = false
    _game.debug_draw_tiles = true
    _game.debug_draw_entities = true
    _game.debug_render_z_index_0 = true
    _game.debug_render_z_index_1 = true

    _game.debug_window_anim = false

    _game.battle_index = 1 // Skip worldmap

    _game.units = [dynamic]Unit {
        Unit { name = "Ramza", sprite_position = { 4, 15 }, stat_health = 10, stat_health_max = 10, stat_speed = 5, stat_move = 5 },
        Unit { name = "Delita", sprite_position = { 3, 15 }, stat_health = 20, stat_health_max = 20, stat_speed = 3, stat_move = 5 },
        Unit { name = "Alma", sprite_position = { 2, 15 }, stat_health = 30, stat_health_max = 30, stat_speed = 6, stat_move = 5 },
        Unit { name = "Wiegraf", sprite_position = { 1, 15 }, stat_health = 10, stat_health_max = 10, stat_speed = 8, stat_move = 5 },
        Unit { name = "Belias", sprite_position = { 0, 14 }, stat_health = 20, stat_health_max = 20, stat_speed = 5, stat_move = 5 },
        Unit { name = "Gaffgarion", sprite_position = { 1, 15 }, stat_health = 30, stat_health_max = 30, stat_speed = 4, stat_move = 5 },
    }
    _game.party = { 0, 1, 2 }
    _game.foes = { 3, 4, 5 }

    engine.asset_load(_game.asset_shader_sprite)
    engine.asset_load(_game.asset_nyan, engine.Image_Load_Options { filter = engine.RENDERER_FILTER_NEAREST })

    engine.asset_load(_game.asset_sound_cancel)
    engine.asset_load(_game.asset_sound_confirm)
    engine.asset_load(_game.asset_sound_invalid)
    engine.asset_load(_game.asset_sound_hit)

    shader_asset := _engine.assets.assets[_game.asset_shader_sprite]
    if shader_asset.info == nil {
        log.debugf("Asset not loaded!")
    } else {
        shader_asset_info := shader_asset.info.(engine.Asset_Info_Shader)
        _game.shader_default = shader_asset_info.shader
    }

    engine.renderer_update_viewport()
    _engine.renderer.ui_camera.zoom = _engine.renderer.ideal_scale
    _engine.renderer.world_camera.zoom = _engine.renderer.ideal_scale
    _engine.renderer.draw_ui = true

    engine.audio_set_volume_main(0.5)
    engine.audio_set_volume_music(0.0)
    engine.audio_set_volume_sound(1.0)

    game_mode_transition(.Title)
}
