package engine

import "core:mem"
import "core:time"

Debug_State :: struct {
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

debug_init :: proc() -> (ok: bool) {
    debug := new(Debug_State)
    _e.debug = debug
    ok = true
    return
}

append_debug_line :: proc(start: Vector2i32, end: Vector2i32, color: Color) {
    if _e.debug.lines_next >= len(_e.debug.lines) {
        return
    }
    _e.debug.lines[_e.debug.lines_next] = { start, end, color }
    _e.debug.lines_next += 1
}

append_debug_rect :: proc(rect: Vector4f32, color: Color) {
    if _e.debug.rects_next >= len(_e.debug.rects) {
        return
    }
    _e.debug.rects[_e.debug.rects_next] = { rect, color }
    _e.debug.rects_next += 1
}

debug_update :: proc() {
    for i := 0; i < len(_e.debug.rects); i += 1 {
        _e.debug.rects[i] = {}
    }
    _e.debug.rects_next = 0
    for i := 0; i < len(_e.debug.lines); i += 1 {
        _e.debug.lines[i] = {}
    }
    _e.debug.lines_next = 0
}

debug_render :: proc() {
    // FIXME:
    // { profiler_zone("draw_debug_rect", PROFILER_COLOR_ENGINE)
    //     for i := 0; i < len(_e.debug.rects); i += 1 {
    //         rect := _e.debug.rects[i]
    //         renderer_draw_fill_rect(&rect.rect, rect.color)
    //     }
    // }
    // { profiler_zone("draw_debug_lines", PROFILER_COLOR_ENGINE)
    //     for i := 0; i < len(_e.debug.lines); i += 1 {
    //         line := _e.debug.lines[i]
    //         renderer_set_draw_color(line.color)
    //         renderer_draw_line(&line.start, &line.end)
    //     }
    // }
}
