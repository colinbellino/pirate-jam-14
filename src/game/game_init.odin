package game

import "../engine"

game_mode_init :: proc() {
    _mem.game.render_enabled = #config(RENDER_ENABLE, true)

    _mem.game.debug_draw_tiles = true
    _mem.game.debug_draw_entities = true
    _mem.game.debug_draw_fog = true
    _mem.game.debug_draw_gl = false
    _mem.game.debug_ui_entity_units = true
    _mem.game.debug_ui_window_game = true
    _mem.game.debug_ui_entity_tiles = false
    _mem.game.debug_ui_entity_units = true
    _mem.game.debug_ui_entity_children = true
    _mem.game.debug_ui_entity_other = true
    _mem.game.debug_draw_top_bar = true

    _mem.game.cheat_act_anywhere = true
    _mem.game.cheat_act_repeatedly = true
    _mem.game.cheat_move_anywhere = true
    _mem.game.cheat_move_repeatedly = true

    _mem.game.asset_image_spritesheet = engine.asset_add("media/art/spritesheet.png", .Image)
    _mem.game.asset_image_tileset =     engine.asset_add("media/art/tileset.png", .Image)
    _mem.game.asset_image_adventurer =  engine.asset_add("media/art/Adventurer01.png", .Image)
    _mem.game.asset_image_player =      engine.asset_add("media/art/Jan.png", .Image)
    _mem.game.asset_image_heart =       engine.asset_add("media/art/Hearts.png", .Image)
    _mem.game.asset_image_cloud =       engine.asset_add("media/art/Kerfuffle.png", .Image)
    _mem.game.asset_image_torch =       engine.asset_add("media/art/flame anim v0.1 with shining light (1).png", .Image)
    _mem.game.asset_image_title =       engine.asset_add("media/art/title.png", .Image)
    _mem.game.asset_shader_sprite =     engine.asset_add("shader_sprite", .Shader)
    _mem.game.asset_shader_swipe =      engine.asset_add("shader_swipe", .Shader)
    _mem.game.asset_shader_line =       engine.asset_add("shader_line", .Shader)
    _mem.game.asset_music_worldmap =    engine.asset_add("media/audio/musics/8-bit (4).ogg", .Audio)
    _mem.game.asset_music_battle =      engine.asset_add("media/audio/musics/8-bit (6).ogg", .Audio)
    _mem.game.asset_sound_cancel =      engine.asset_add("media/audio/sounds/cancel.mp3", .Audio)
    _mem.game.asset_sound_confirm =     engine.asset_add("media/audio/sounds/confirm.mp3", .Audio)
    _mem.game.asset_sound_invalid =     engine.asset_add("media/audio/sounds/invalid.mp3", .Audio)
    _mem.game.asset_sound_hit =         engine.asset_add("media/audio/sounds/hit.mp3", .Audio)
    _mem.game.asset_map_rooms =         engine.asset_add("media/levels/rooms.ldtk", .Map)

    engine.asset_load(_mem.game.asset_sound_cancel)
    engine.asset_load(_mem.game.asset_sound_confirm)
    engine.asset_load(_mem.game.asset_sound_invalid)
    engine.asset_load(_mem.game.asset_sound_hit)
    engine.asset_load(_mem.game.asset_map_rooms)

    engine.audio_set_volume_main(GAME_VOLUME_MAIN)
    engine.audio_set_volume_music(0.0)
    engine.audio_set_volume_sound(1.0)

    palettes_init()
    renderer_commands_init()

    game_mode_transition(.Title)
}
