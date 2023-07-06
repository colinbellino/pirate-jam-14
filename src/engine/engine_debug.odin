package engine

import "core:mem"
import "core:time"

Debug_State :: struct {
    allocator:              mem.Allocator,
    last_reload:            time.Time,
    file_watches:           [200]File_Watch,
    file_watches_count:     int,
    start_game:             bool,
    save_memory:            int,
    load_memory:            int,
    game_counter:           int,
    lines:                  [100]Debug_Line,
    lines_next:             i32,
    rects:                  [100]Debug_Rect,
    rects_next:             i32,
}

debug_init :: proc(allocator := context.allocator) -> (ok: bool) {
    context.allocator = allocator
    debug := new(Debug_State, allocator)
    debug.allocator = allocator
    _engine.debug = debug
    ok = true
    return
}

append_debug_line :: proc(start: Vector2i32, end: Vector2i32, color: Color) {
    if _engine.debug.lines_next >= len(_engine.debug.lines) {
        return
    }
    _engine.debug.lines[_engine.debug.lines_next] = { start, end, color }
    _engine.debug.lines_next += 1
}

append_debug_rect :: proc(rect: RectF32, color: Color) {
    if _engine.debug.rects_next >= len(_engine.debug.rects) {
        return
    }
    _engine.debug.rects[_engine.debug.rects_next] = { rect, color }
    _engine.debug.rects_next += 1
}

debug_update :: proc() {
    for i := 0; i < len(_engine.debug.rects); i += 1 {
        _engine.debug.rects[i] = {}
    }
    _engine.debug.rects_next = 0
    for i := 0; i < len(_engine.debug.lines); i += 1 {
        _engine.debug.lines[i] = {}
    }
    _engine.debug.lines_next = 0
}

debug_render :: proc() {
    // FIXME:
    // { profiler_zone("draw_debug_rect", PROFILER_COLOR_RENDER)
    //     for i := 0; i < len(_engine.debug.rects); i += 1 {
    //         rect := _engine.debug.rects[i]
    //         renderer_draw_fill_rect(&rect.rect, rect.color)
    //     }
    // }
    // { profiler_zone("draw_debug_lines", PROFILER_COLOR_RENDER)
    //     for i := 0; i < len(_engine.debug.lines); i += 1 {
    //         line := _engine.debug.lines[i]
    //         renderer_set_draw_color(line.color)
    //         renderer_draw_line(&line.start, &line.end)
    //     }
    // }
}
