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

game_update :: proc() -> (quit: bool) {
    quit = engine.platform_frame()

    if platform.keys[.SPACE].released {
        r := engine.Renderers.None
        if renderer.renderer == .None {
            r = .OpenGL
        }

        engine.renderer_deinit()
        ok: bool
        renderer, ok = engine.renderer_init(r, platform.window)
    }

    if quit {
        engine.renderer_deinit()
        engine.platform_deinit()
    }

    return
}
