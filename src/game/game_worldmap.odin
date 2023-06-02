package game

import "core:log"
import "core:strings"
import "core:fmt"
import "core:runtime"
import "core:mem"
import "core:encoding/json"

import "../engine"

Game_Mode_Worldmap :: struct {
    entities:             [dynamic]Entity,
    level:                Level,
}

game_mode_update_worldmap :: proc(app: ^engine.App) {
    if game_mode_enter(game_mode_exit_proc) {
        context.allocator = game.game_mode_allocator;
        game.world_data = new(Game_Mode_Worldmap);

        world_asset := &app.assets.assets[game.asset_worldmap];
        asset_info, asset_ok := world_asset.info.(engine.Asset_Info_Map);
        assert(asset_ok);
        game.world_data.level, game.world_data.entities = make_level(asset_info.ldtk, 0, game.tileset_assets, game.game_allocator);
    }

    if game.player_inputs.mouse_left.released && game.debug_entity_under_mouse != 0{
        entity := game.debug_entity_under_mouse;
        component_meta, has_meta := game.entities.components_meta[game.debug_entity_under_mouse];
        if has_meta {
            battle_index, battle_index_exists := component_meta.value["battle_index"];
            if battle_index_exists {
                game.battle_index = int(battle_index.(json.Integer));
                game_mode_transition(.Battle);
            }
        }
    }

    if engine.ui_window(app.ui, "Worldmap", { 400, 400, 200, 100 }, { .NO_CLOSE, .NO_RESIZE }) {
        engine.ui_layout_row(app.ui, { -1 }, 0);
        if .SUBMIT in engine.ui_button(app.ui, "Battle 1") {
            game.battle_index = 0;
            game_mode_transition(.Battle);
        }
        if .SUBMIT in engine.ui_button(app.ui, "Battle 2") {
            game.battle_index = 1;
            game_mode_transition(.Battle);
        }
        if .SUBMIT in engine.ui_button(app.ui, "Battle 3") {
            game.battle_index = 2;
            game_mode_transition(.Battle);
        }
    }

    game_mode_exit_proc :: proc() {
        log.debug("Worldmap exit");
        for entity in game.world_data.entities {
            entity_delete(entity, &game.entities);
        }
    }
}
