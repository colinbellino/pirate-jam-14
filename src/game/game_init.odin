package game

import "core:log"
import "core:os"
import "core:slice"
import "core:math/rand"

import engine "../engine_v2"

game_mode_init :: proc() {
    // _mem.game.debug_draw_grid = true
    _mem.game.debug_draw_tiles = true
    _mem.game.debug_draw_entities = true
    _mem.game.debug_draw_fog = true
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
    _mem.game.asset_shader_sprite =     engine.asset_add("media/shaders/shader_sprite.glsl", .Shader)
    _mem.game.asset_shader_sprite_aa =  engine.asset_add("media/shaders/shader_aa_sprite.glsl", .Shader)
    _mem.game.asset_shader_grid =       engine.asset_add("media/shaders/shader_grid.glsl", .Shader)
    _mem.game.asset_shader_test =       engine.asset_add("media/shaders/shader_test.glsl", .Shader)
    _mem.game.asset_shader_line =       engine.asset_add("media/shaders/shader_line.glsl", .Shader)
    _mem.game.asset_shader_swipe =      engine.asset_add("media/shaders/shader_swipe.glsl", .Shader)
    _mem.game.asset_shader_fog =        engine.asset_add("media/shaders/shader_fog.glsl", .Shader)
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

    engine.asset_load(_mem.game.asset_shader_sprite)
    engine.asset_load(_mem.game.asset_shader_sprite_aa)
    engine.asset_load(_mem.game.asset_shader_line)
    engine.asset_load(_mem.game.asset_shader_grid)
    engine.asset_load(_mem.game.asset_shader_swipe)
    engine.asset_load(_mem.game.asset_shader_fog)

    // FIXME: asset
    // engine.asset_load(_mem.game.asset_image_nyan, engine.Asset_Load_Options_Image { filter = engine.RENDERER_FILTER_NEAREST })
    // engine.asset_load(_mem.game.asset_image_units, engine.Asset_Load_Options_Image { engine.RENDERER_FILTER_NEAREST, engine.RENDERER_WRAP_CLAMP_TO_EDGE })

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

    {
        // FIXME: viewport
        // engine.renderer_update_viewport()
        // FIXME: ideal_scale
        // _mem.renderer.ui_camera.zoom = _mem.renderer.ideal_scale
        // _mem.renderer.world_camera.zoom = _mem.renderer.ideal_scale
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
    }

    game_mode_transition(.Title)
}
