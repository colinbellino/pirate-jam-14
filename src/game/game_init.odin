package game

import "core:log"
import "core:os"
import "core:slice"
import "core:math/rand"

import engine "../engine_v2"

game_mode_init :: proc() {
    _mem.game.debug_draw_tiles = true
    _mem.game.debug_draw_entities = true
    _mem.game.debug_draw_fog = true
    _mem.game.debug_draw_gl = true
    _mem.game.debug_ui_entity_units = true
    _mem.game.debug_ui_window_game = true
    _mem.game.debug_ui_entity_tiles = false
    _mem.game.debug_ui_entity_units = true
    _mem.game.debug_ui_entity_children = false
    _mem.game.debug_ui_entity_other = true

    _mem.game.cheat_act_anywhere = true
    _mem.game.cheat_act_repeatedly = true
    _mem.game.cheat_move_anywhere = true
    _mem.game.cheat_move_repeatedly = true

    // TODO: generate the asset list in the build process
    _mem.game.asset_map_world =         engine.asset_add("media/levels/worldmap.ldtk", .Map)
    _mem.game.asset_map_areas =         engine.asset_add("media/levels/areas.ldtk", .Map)
    _mem.game.asset_image_spritesheet = engine.asset_add("media/art/spritesheet.png", .Image)
    _mem.game.asset_image_units =       engine.asset_add("media/art/units.png", .Image)
    _mem.game.asset_image_battle_bg =   engine.asset_add("media/art/battle_background.png", .Image)
    _mem.game.asset_shader_sprite =     engine.asset_add("shader_sprite", .Shader)
    _mem.game.asset_shader_swipe =      engine.asset_add("shader_swipe", .Shader)
    _mem.game.asset_shader_line =       engine.asset_add("shader_line", .Shader)
    // _mem.game.asset_shader_sprite_aa =  engine.asset_add("media/shaders/shader_aa_sprite.glsl", .Shader)
    // _mem.game.asset_shader_grid =       engine.asset_add("media/shaders/shader_grid.glsl", .Shader)
    // _mem.game.asset_shader_test =       engine.asset_add("media/shaders/shader_test.glsl", .Shader)
    // _mem.game.asset_shader_swipe =      engine.asset_add("media/shaders/shader_swipe.glsl", .Shader)
    // _mem.game.asset_shader_fog =        engine.asset_add("media/shaders/shader_fog.glsl", .Shader)
    _mem.game.asset_image_nyan =        engine.asset_add("media/art/nyan.png", .Image)
    _mem.game.asset_music_worldmap =    engine.asset_add("media/audio/musics/8-bit (4).ogg", .Audio)
    _mem.game.asset_music_battle =      engine.asset_add("media/audio/musics/8-bit (6).ogg", .Audio)
    _mem.game.asset_sound_cancel =      engine.asset_add("media/audio/sounds/cancel.mp3", .Audio)
    _mem.game.asset_sound_confirm =     engine.asset_add("media/audio/sounds/confirm.mp3", .Audio)
    _mem.game.asset_sound_invalid =     engine.asset_add("media/audio/sounds/invalid.mp3", .Audio)
    _mem.game.asset_sound_hit =         engine.asset_add("media/audio/sounds/hit.mp3", .Audio)

    external_id_unit := engine.asset_register_external({ load_proc = load_unit_from_file_path, print_proc = print_unit_asset })
    append(&_mem.game.asset_units, engine.asset_add("media/units/unit_ramza.json", .External, external_id = external_id_unit))
    append(&_mem.game.asset_units, engine.asset_add("media/units/unit_delita.json", .External, external_id = external_id_unit))
    append(&_mem.game.asset_units, engine.asset_add("media/units/unit_alma.json", .External, external_id = external_id_unit))
    append(&_mem.game.asset_units, engine.asset_add("media/units/unit_agrias.json", .External, external_id = external_id_unit))
    append(&_mem.game.asset_units, engine.asset_add("media/units/unit_mustadio.json", .External, external_id = external_id_unit))
    append(&_mem.game.asset_units, engine.asset_add("media/units/unit_boco.json", .External, external_id = external_id_unit))
    append(&_mem.game.asset_units, engine.asset_add("media/units/unit_rapha.json", .External, external_id = external_id_unit))
    append(&_mem.game.asset_units, engine.asset_add("media/units/unit_wiegraf.json", .External, external_id = external_id_unit))
    append(&_mem.game.asset_units, engine.asset_add("media/units/unit_belias.json", .External, external_id = external_id_unit))
    append(&_mem.game.asset_units, engine.asset_add("media/units/unit_gaffgarion.json", .External, external_id = external_id_unit))
    append(&_mem.game.asset_units, engine.asset_add("media/units/unit_lavian.json", .External, external_id = external_id_unit))
    append(&_mem.game.asset_units, engine.asset_add("media/units/unit_alicia.json", .External, external_id = external_id_unit))
    append(&_mem.game.asset_units, engine.asset_add("media/units/unit_ladd.json", .External, external_id = external_id_unit))
    append(&_mem.game.asset_units, engine.asset_add("media/units/unit_cidolfus.json", .External, external_id = external_id_unit))
    append(&_mem.game.asset_units, engine.asset_add("media/units/unit_snowpal.json", .External, external_id = external_id_unit))
    append(&_mem.game.asset_units, engine.asset_add("media/units/unit_stalactite.json", .External, external_id = external_id_unit))

    external_id_ability := engine.asset_register_external({ load_proc = load_ability_from_file_path, print_proc = print_ability_asset })
    append(&_mem.game.asset_abilities, engine.asset_add("media/abilities/ability_snowball.json", .External, external_id = external_id_ability))
    append(&_mem.game.asset_abilities, engine.asset_add("media/abilities/ability_push.json", .External, external_id = external_id_ability))

    for unit_asset in _mem.game.asset_units {
        engine.asset_load(unit_asset)
    }

    for ability_asset in _mem.game.asset_abilities {
        engine.asset_load(ability_asset)
    }

    engine.asset_load(_mem.game.asset_sound_cancel)
    engine.asset_load(_mem.game.asset_sound_confirm)
    engine.asset_load(_mem.game.asset_sound_invalid)
    engine.asset_load(_mem.game.asset_sound_hit)

    engine.audio_set_volume_main(GAME_VOLUME_MAIN)
    engine.audio_set_volume_music(0.0)
    engine.audio_set_volume_sound(1.0)

    for i := 0; i < len(_mem.game.asset_abilities); i += 1 {
        asset_id := _mem.game.asset_abilities[i]
        asset_info, asset_ok := engine.asset_get_asset_info_external(asset_id, Asset_Ability)
        assert(asset_ok)
        append(&_mem.game.abilities, create_ability_from_asset(asset_id, asset_info))
    }
    assert(len(_mem.game.abilities) == len(_mem.game.asset_abilities), "couldn't create abilities")

    palettes_init()
    renderer_commands_init()

    game_mode_transition(.Title)
}
