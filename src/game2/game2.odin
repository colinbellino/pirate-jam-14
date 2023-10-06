package game2

import "core:log"
import "../tools"
import engine "../engine2"

platform: ^engine.Platform
renderer: ^engine.Renderer

game_init :: proc() -> bool {
    // tools.create_arena()
    ok: bool
    platform, ok = engine.platform_init({ 1920/2, 1080/2 })
    renderer, ok = engine.renderer_init(.OpenGL, platform.window)
    return ok
}

i := 0
game_update :: proc() -> (quit: bool) {
    quit = engine.platform_frame()

    {
        current, previous := tools.mem_get_usage()
        diff := current - previous
        log.debugf("i: %v | mem: %v/%v/%v | renderer: %v", i, previous, current, diff, renderer.renderer)
        if i == 100 {
            engine.renderer_deinit()
            ok: bool
            renderer, ok = engine.renderer_init(.None, platform.window)
        }
        i += 1
    }

    return
}
