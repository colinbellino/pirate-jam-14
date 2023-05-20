package snowball

import "core:log"
import "core:strings"
import "core:fmt"
import "core:runtime"
import "core:mem"

import "../engine"

Game_Mode_Battle :: struct {
    entities:             [dynamic]Entity,
    level:                Level,
}

game_mode_update_battle :: proc () {
    if game_mode_enter() {
        context.allocator = game.game_mode_allocator;
        game.battle_data = new(Game_Mode_Battle);

        areas_asset := &app.assets.assets[game.asset_areas];
        asset_info, asset_ok := areas_asset.info.(engine.Asset_Info_Map);
        assert(asset_ok);
        game.battle_data.level, game.battle_data.entities = make_level(asset_info.ldtk, 0, game.tileset_assets, game.game_allocator);

        log.debugf("Battle:           %v", game.battle_index);
        // log.debugf("game.battle_data: %v | %v", game.battle_data.level, game.battle_data.entities);
    }

    if engine.ui_window(app.ui, "Battle", { 400, 400, 200, 100 }, { .NO_CLOSE, .NO_RESIZE }) {
        engine.ui_layout_row(app.ui, { -1 }, 0);
        engine.ui_label(app.ui, fmt.tprintf("Battle index: %v", game.battle_index));
    }

    if game_mode_exit(.Battle) {
        log.debug("Battle exit");
        for entity in game.battle_data.entities {
            entity_delete(entity, &game.entities);
        }
    }
}
