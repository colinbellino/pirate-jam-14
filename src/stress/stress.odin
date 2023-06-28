package game

import "core:fmt"
import "core:log"
import "core:math/linalg"
import "core:math/rand"
import "core:mem"
import "core:os"
import "core:runtime"
import "core:slice"
import "core:sort"
import "core:strings"

import "../engine"

Vector2i32              :: engine.Vector2i32
Vector2f32              :: engine.Vector2f32
Rect                    :: engine.Rect
RectF32                 :: engine.RectF32
Color                   :: engine.Color
array_cast              :: linalg.array_cast

MEM_BASE_ADDRESS        :: 2 * mem.Terabyte
MEM_GAME_SIZE           :: 1 * mem.Megabyte
NATIVE_RESOLUTION       :: Vector2i32 { 256, 144 }
CONTROLLER_DEADZONE     :: 15_000
PROFILER_COLOR_RENDER   :: 0x550000
CLEAR_COLOR             :: Color { 255, 0, 255, 255 } // This is supposed to never show up, so it's a super flashy color. If you see it, something is broken.
VOID_COLOR              :: Color { 100, 100, 100, 255 }
WINDOW_BORDER_COLOR     :: Color { 0, 0, 0, 255 }
GRID_SIZE               :: 8
GRID_SIZE_V2            :: Vector2i32 { GRID_SIZE, GRID_SIZE }
LETTERBOX_COLOR         :: Color { 10, 10, 10, 255 }
LETTERBOX_SIZE          :: Vector2i32 { 40, 18 }
LETTERBOX_TOP           :: Rect { 0, 0,                                      NATIVE_RESOLUTION.x, LETTERBOX_SIZE.y }
LETTERBOX_BOTTOM        :: Rect { 0, NATIVE_RESOLUTION.y - LETTERBOX_SIZE.y, NATIVE_RESOLUTION.x, LETTERBOX_SIZE.y }
LETTERBOX_LEFT          :: Rect { 0, 0,                                      LETTERBOX_SIZE.x, NATIVE_RESOLUTION.y }
LETTERBOX_RIGHT         :: Rect { NATIVE_RESOLUTION.x - LETTERBOX_SIZE.x, 0, LETTERBOX_SIZE.x, NATIVE_RESOLUTION.y }
HUD_SIZE                :: Vector2i32 { 40, 20 }
HUD_RECT                :: Rect { 0, NATIVE_RESOLUTION.y - HUD_SIZE.y, NATIVE_RESOLUTION.x, HUD_SIZE.y }
HUD_COLOR               :: Color { 255, 255, 255, 255 }

ENTITY_SIZE             :: 16;
ENTITIES_COUNT          :: 2_000;

Game_Mode_Proc :: #type proc()

Game_State :: struct {
    _engine:                    ^engine.Engine_State,
    // arena:                      ^mem.Arena,
    game_allocator:             runtime.Allocator,
    arena:                      ^mem.Arena,
    // window_size:                Vector2i32,
    initialized:                bool,
    asset_placeholder:          engine.Asset_Id,
    texture_placeholder:        ^engine.Texture,
    entity_position:            [ENTITIES_COUNT]Vector2i32,
    entity_color:               [ENTITIES_COUNT]Color,
    entity_rect:                [ENTITIES_COUNT]Rect,
}

@(private)
_game: ^Game_State

@(export)
game_init :: proc() -> rawptr {
    app := engine.engine_init(MEM_BASE_ADDRESS, MEM_GAME_SIZE)

    _game = new(Game_State)
    _game.arena = new(mem.Arena)
    game_allocator := engine.platform_make_arena_allocator(.Game, MEM_GAME_SIZE, _game.arena, context.allocator)
    _game.game_allocator = game_allocator
    if engine.PROFILER {
        _game.arena = cast(^mem.Arena)(cast(^engine.ProfiledAllocatorData)_game.game_allocator.data).backing_allocator.data
    } else {
        _game.arena = cast(^mem.Arena)_game.game_allocator.data
    }
    _game._engine = app

    return &_game
}

@(export)
game_update :: proc(game: ^Game_State) -> (quit: bool, reload: bool) {
    engine.profiler_frame_mark()
    engine.platform_frame_start()

    context.allocator = _game.game_allocator


    window_size := Vector2i32 { 1920, 1080 }
    rendering_scale : i32 = 7

    { engine.profiler_zone("game_update")
        for entity_index := 0; entity_index < ENTITIES_COUNT; entity_index += 1 {
            entity_position := &_game.entity_position[entity_index];
            entity_position.x = rand.int31_max((window_size.x - ENTITY_SIZE) / rendering_scale);
            entity_position.y = rand.int31_max((window_size.y - ENTITY_SIZE) / rendering_scale);

            entity_color := &_game.entity_color[entity_index];
            entity_color.r = u8(rand.int31_max(255));
            entity_color.g = u8(rand.int31_max(255));
            entity_color.b = u8(rand.int31_max(255));
            entity_color.a = 255;
        }

        if _game._engine.platform.keys[.F5].released {
            reload = true
        }
        if _game._engine.platform.quit_requested || _game._engine.platform.keys[.ESCAPE].released {
            quit = true
        }

        engine.platform_set_window_title(get_window_title())
    }

    game_render()

    engine.platform_frame_end()

    return
}

@(export)
game_quit :: proc(game: Game_State) { }

@(export)
window_open :: proc() {
    engine.platform_open_window("", { 1920, 1080 })
}

@(export)
window_close :: proc(game: Game_State) { }

get_window_title :: proc() -> string {
    return fmt.tprintf("Snowball (Renderer: %v | Refresh rate: %3.0fHz | FPS: %5.0f)", engine.RENDERER, f32(_game._engine.renderer.refresh_rate), f32(_game._engine.platform.fps))
}

game_render :: proc() {
    engine.profiler_zone("game_render", PROFILER_COLOR_RENDER)

    engine.renderer_render_start()

    engine.renderer_clear(VOID_COLOR)

    if engine.renderer_is_enabled() == false {
        log.warn("Renderer disabled")
        return
    }

    if _game._engine.platform.window_resized {
        engine.platform_resize_window(NATIVE_RESOLUTION)
    }

    { engine.profiler_zone("render_entities", PROFILER_COLOR_RENDER);
        engine.renderer_draw_quad_batch()
    }

    engine.renderer_render_end()
}
