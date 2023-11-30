package game

import "core:log"

game_mode_title :: proc() {
    if true { // Skip worldmap
        _mem.game.battle_index = 1
        game_mode_transition(.WorldMap)
        return
    }

    game_mode_transition(.WorldMap)
}
