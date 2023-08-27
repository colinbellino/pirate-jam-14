package game

import "../engine"

game_mode_init :: proc() {
    // TODO: generate the asset list in the build process
    _game.asset_worldmap          = engine.asset_add("media/levels/worldmap.ldtk", .Map)
    _game.asset_areas             = engine.asset_add("media/levels/areas.ldtk", .Map)
    _game.asset_tilemap           = engine.asset_add("media/art/spritesheet.png", .Image)
    _game.asset_battle_background = engine.asset_add("media/art/battle_background_xl.png", .Image)
    _game.asset_shader_sprite     = engine.asset_add("media/shaders/shader_aa_sprite.glsl", .Shader)
    _game.asset_shader_sprite_aa  = engine.asset_add("media/shaders/shader_sprite.glsl", .Shader)

    _game.draw_hud = false
    _game.debug_draw_tiles = true
    _game.debug_draw_entities = true
    _game.debug_render_z_index_0 = true
    _game.debug_render_z_index_1 = true

    _game.debug_window_anim = false

    _game.battle_index = 1 // Skip worldmap

    _game.units = [dynamic]Unit {
        Unit { name = "Ramza", sprite = { 4, 15 }, stat_health = 1, stat_speed = 5 },
        Unit { name = "Delita", sprite = { 3, 15 }, stat_health = 2, stat_speed = 3 },
        Unit { name = "Alma", sprite = { 2, 15 }, stat_health = 3, stat_speed = 6 },
        Unit { name = "Wiegraf", sprite = { 1, 15 }, stat_health = 1, stat_speed = 8 },
        Unit { name = "Belias", sprite = { 0, 14 }, stat_health = 2, stat_speed = 5 },
        Unit { name = "Gaffgarion", sprite = { 1, 15 }, stat_health = 3, stat_speed = 4 },
    }
    _game.party = { 0, 1, 2 }
    _game.foes = { 3, 4, 5 }

    engine.asset_load(_game.asset_shader_sprite)
    shader_asset := _game._engine.assets.assets[_game.asset_shader_sprite]
    shader_asset_info := shader_asset.info.(engine.Asset_Info_Shader)
    _game.shader_default = shader_asset_info.shader

    game_mode_transition(.Title)
    game_mode_end()
}
