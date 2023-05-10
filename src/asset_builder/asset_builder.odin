package asset_builder

import "core:log"

import "../engine"
import "../game"

main :: proc() {
    context.logger = log.create_console_logger();

    app := engine.App {}
    game := game.Game_State {};
    log.debugf("game: %v", game);
    log.debugf("app: %v", app);
}
