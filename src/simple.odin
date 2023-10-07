package simple

import game "game2"

main :: proc() {
    game.game_start()

    quit := false
    for quit == false {
        quit = game.game_update()
    }

    game.game_quit()
}
