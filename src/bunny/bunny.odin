package bunny

import "core:fmt"
import "core:log"
import "core:mem"
import "core:mem/virtual"
import "core:runtime"
import "core:math/rand"
import "../engine"
import tracy "../odin-tracy"

Logger_State :: engine.Logger_State
Assets_State :: engine.Assets_State
Entity_State :: engine.Entity_State
Renderer_State :: engine.Renderer_State
Platform_State :: engine.Platform_State
Audio_State :: engine.Audio_State
Animation_State :: engine.Animation_State
Core_State :: engine.Core_State

App_Memory :: struct {
    logger:     ^Logger_State,
    assets:     ^Assets_State,
    entity:     ^Entity_State,
    renderer:   ^Renderer_State,
    platform:   ^Platform_State,
    audio:      ^Audio_State,
    animation:  ^Animation_State,
    core:       ^Core_State,
}

@(private="package")
_mem: ^App_Memory

MAX_BUNNIES        :: 50_000
MAX_BATCH_ELEMENTS :: 8192
bunny_texture: engine.Asset_Id
shader_sprite: engine.Asset_Id
bunnies_count := 0
bunnies := [MAX_BUNNIES]Bunny {}

Bunny :: struct {
    position: engine.Vector2f32,
    speed:    engine.Vector2f32,
    color:    engine.Color,
}

@(export) app_init :: proc() -> rawptr {
    ok: bool
    _mem = new(App_Memory, runtime.default_allocator())
    _mem.logger = engine.logger_init()
    context.logger = engine.logger_get_logger()
    _mem.assets = engine.asset_init()
    _mem.entity = engine.entity_init()
    _mem.platform = engine.platform_init()
    _mem.audio = engine.audio_init()
    _mem.animation = engine.animation_init()
    _mem.core = engine.core_init()

    screen_width : i32 = 800
    screen_height : i32 = 450
    engine.platform_open_window({ screen_width, screen_height })
    _mem.renderer = engine.renderer_init(_mem.platform.window, { f32(screen_width), f32(screen_height) })

    bunny_texture = engine.asset_add("media/art/nyan.png", .Image)
    engine.asset_load(bunny_texture)
    shader_sprite = engine.asset_add("media/shaders/shader_sprite.glsl", .Shader)
    engine.asset_load(shader_sprite)

    engine.renderer_update_viewport()
    _mem.renderer.world_camera.position = { f32(screen_width) / 2, f32(screen_height) / 2, 0 }
    _mem.renderer.world_camera.zoom = 1
    engine.renderer_update_camera_projection_matrix()
    engine.renderer_update_camera_view_projection_matrix()

    return _mem
}

@(export) app_update :: proc(app_memory: ^App_Memory) -> (quit: bool, reload: bool) {
    context.logger = engine.logger_get_logger()

    engine.platform_set_window_title(fmt.tprintf("Bunnymark: %vFPS", _mem.platform.actual_fps))
    engine.platform_frame()

    if _mem.platform.quit_requested {
        quit = true
    }

    asset_image, asset_image_ok := engine.asset_get_asset_info_image(bunny_texture)
    assert(asset_image_ok)
    asset_shader, asset_shader_ok := engine.asset_get_asset_info_shader(shader_sprite)
    assert(asset_shader_ok)

    if _mem.platform.keys[.LEFT].down {
        _mem.renderer.world_camera.position.x -= _mem.platform.delta_time / 5
        engine.renderer_update_camera_projection_matrix()
        engine.renderer_update_camera_view_projection_matrix()
    }
    if _mem.platform.keys[.RIGHT].down {
        _mem.renderer.world_camera.position.x += _mem.platform.delta_time / 5
        engine.renderer_update_camera_projection_matrix()
        engine.renderer_update_camera_view_projection_matrix()
    }
    if _mem.platform.keys[.UP].down {
        _mem.renderer.world_camera.position.y -= _mem.platform.delta_time / 5
        engine.renderer_update_camera_projection_matrix()
        engine.renderer_update_camera_view_projection_matrix()
    }
    if _mem.platform.keys[.DOWN].down {
        _mem.renderer.world_camera.position.y += _mem.platform.delta_time / 5
        engine.renderer_update_camera_projection_matrix()
        engine.renderer_update_camera_view_projection_matrix()
    }

    if _mem.platform.mouse_keys[engine.BUTTON_LEFT].down {
        for i := 0; i < 100; i += 1 {
            if bunnies_count < MAX_BUNNIES {
                bunnies[bunnies_count].position = { f32(_mem.platform.mouse_position.x), f32(_mem.platform.mouse_position.y) }
                bunnies[bunnies_count].speed.x = rand.float32_range(-250, 250) / 60
                bunnies[bunnies_count].speed.y = rand.float32_range(-250, 250) / 60
                bunnies[bunnies_count].color = {
                    f32(rand.float32_range(50, 240)) / 255,
                    f32(rand.float32_range(80, 240)) / 255,
                    f32(rand.float32_range(100, 240)) / 255,
                    1,
                }
                bunnies_count += 1
            }
        }
    }

    if _mem.platform.mouse_keys[engine.BUTTON_RIGHT].down {
        bunnies_count = 0
    }

    for i := 0; i < bunnies_count; i += 1 {
        bunnies[i].position.x += bunnies[i].speed.x
        bunnies[i].position.y += bunnies[i].speed.y

        if ((i32(bunnies[i].position.x) + asset_image.width / 2) > i32(f32(_mem.platform.window_size.x))) || ((i32(bunnies[i].position.x) + asset_image.width / 2) < 0) {
            bunnies[i].speed.x *= -1
        }
        if ((i32(bunnies[i].position.y) + asset_image.height / 2) > i32(f32(_mem.platform.window_size.y))) || ((i32(bunnies[i].position.y) + asset_image.height / 2 - 40) < 0) {
            bunnies[i].speed.y *= -1
        }
    }

    {
        engine.renderer_clear({ 0.9, 0.9, 0.9, 1 })

        for i := 0; i < bunnies_count; i += 1 {
            engine.renderer_push_quad(
                position = bunnies[i].position,
                size = { 128, 128 },
                color = bunnies[i].color,
                texture = asset_image,
                texture_coordinates = { 0, 0 },
                texture_size = { 1 / f32(6), 1 },
                shader = asset_shader,
            )
        }
    }

    {
        engine.ui_text("bunnies: %v", bunnies_count)
        engine.ui_text("batched draw calls: %v", "TODO:")
        @(static) actual_fps_plot := engine.Statistic_Plot {}
        engine.ui_statistic_plots(&actual_fps_plot, f32(_mem.platform.actual_fps), "actual_fps", min = 0, max = 300)
        @(static) locked_fps_plot := engine.Statistic_Plot {}
        engine.ui_statistic_plots(&locked_fps_plot, f32(_mem.platform.locked_fps), "locked_fps", min = 0, max = 300)
    }

    return
}

@(export) app_reload :: proc(app_memory: ^App_Memory) {}

@(export) app_quit :: proc(app_memory: ^App_Memory) {}
