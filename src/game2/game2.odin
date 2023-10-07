package game2

import "core:log"
import "core:runtime"
import "core:fmt"
import "core:os"
import "core:strings"
import "../tools"
import engine "../engine2"

platform: ^engine.Platform
renderer: ^engine.Renderer

game_start :: proc() -> (ok: bool) {
    // tools.create_arena()
    platform, ok = engine.platform_init({ 1920/2, 1080/2 })
    context.temp_allocator = platform.temp_allocator
    context.allocator = platform.allocator
    renderer, ok = engine.renderer_init(.OpenGL, platform.window)
    return
}

tick := 0
game_update :: proc() -> (quit: bool) {
    // context = engine.platform_context()
    context.allocator = platform.allocator
    engine.platform_frame()

    title, changed := tools.mem_get_diff()
    if changed {
        fmt.printf("%v <- tick %v\n", title, tick)
    }
    // engine.platform_set_window_title(strings.clone_to_cstring(title, context.temp_allocator))

    // if platform.keys[.SPACE].released {
    //     r := engine.Renderers.None
    //     if renderer.renderer == .None {
    //         r = .OpenGL
    //     }

    //     engine.renderer_deinit()
    //     ok: bool
    //     renderer, ok = engine.renderer_init(r, platform.window)
    // }

    quit = platform.quit_requested
    tick += 1

    free_all(context.temp_allocator)

    return
}

game_quit :: proc() {
    // context = engine.platform_context()
    engine.renderer_deinit()
    engine.platform_deinit()
}
