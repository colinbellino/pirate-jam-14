package game2

import "core:log"
import "core:runtime"
import "core:fmt"
import "core:os"
import "../tools"
import engine "../engine2"

platform: ^engine.Platform
renderer: ^engine.Renderer

game_start :: proc() -> bool {
    // tools.create_arena()
    // context.allocator = os.heap_allocator()
    ok: bool
    platform, ok = engine.platform_init({ 1920/2, 1080/2 })
    context.allocator = platform.allocator
    renderer, ok = engine.renderer_init(.OpenGL, platform.window)
    return ok
}

game_update :: proc() -> (quit: bool) {
    if engine.platform_frame() {
        if platform.keys[.SPACE].released {
            r := engine.Renderers.None
            if renderer.renderer == .None {
                r = .OpenGL
            }

            engine.renderer_deinit()
            ok: bool
            renderer, ok = engine.renderer_init(r, platform.window)
        }

        quit = platform.quit_requested
    }

    return
}

game_quit :: proc() {
    engine.renderer_deinit()
    engine.platform_deinit()
}
