package engine

import "core:fmt"
import "core:log"
import "core:mem"
import "core:os"
import "core:runtime"
import "core:strings"
import "core:time"

Logger_State :: struct {
    logger:             runtime.Logger,
    buffer_updated:     bool,
    lines:              [dynamic]Logger_Line,
    data:               log.File_Console_Logger_Data,
}

Logger_Line :: struct {
    level:              log.Level,
    text:               string,
}

logger_init :: proc() -> (ok: bool) {
    context.allocator = _e.allocator

    _e.logger = new(Logger_State)
    _e.logger.logger = log.create_console_logger(.Debug, { .Level, .Terminal_Color })

    if IN_GAME_LOGGER {
        game_console_logger := log.Logger { logger_proc, &_e.logger.data, .Debug, { .Level, .Terminal_Color, .Time } }
        _e.logger.logger = log.create_multi_logger(game_console_logger, _e.logger.logger)
    }

    return true
}

logger_proc :: proc(data: rawptr, level: log.Level, text: string, options: log.Options, location := #caller_location) {
    context.allocator = _e.allocator
    content := strings.clone(_string_logger_proc(data, level, text, options, location))
    append(&_e.logger.lines, Logger_Line { level, content })
    _e.logger.buffer_updated = true
}

@(private="file")
_string_logger_proc :: proc(logger_data: rawptr, level: log.Level, text: string, options: log.Options, location := #caller_location) -> string {
    context.allocator = _e.allocator
    data := cast(^log.File_Console_Logger_Data)logger_data
    h: os.Handle = os.stdout if level <= log.Level.Error else os.stderr
    if data.file_handle != os.INVALID_HANDLE {
        h = data.file_handle
    }
    backing: [1024]byte //NOTE(Hoej): 1024 might be too much for a header backing, unless somebody has really long paths.
    buf := strings.builder_from_bytes(backing[:])

    // log.do_level_header(options, level, &buf)

    when time.IS_SUPPORTED {
        if log.Full_Timestamp_Opts & options != nil {
            fmt.sbprint(&buf, "[")
            t := time.now()
            y, m, d := time.date(t)
            h, min, s := time.clock(t)
            if .Date in options { fmt.sbprintf(&buf, "%d-%02d-%02d ", y, m, d)    }
            if .Time in options { fmt.sbprintf(&buf, "%02d:%02d:%02d", h, min, s) }
            fmt.sbprint(&buf, "] ")
        }
    }

    log.do_location_header(options, &buf, location)

    if .Thread_Id in options {
        // NOTE(Oskar): not using context.thread_id here since that could be
        // incorrect when replacing context for a thread.
        fmt.sbprintf(&buf, "[{}] ", os.current_thread_id())
    }

    if data.ident != "" {
        fmt.sbprintf(&buf, "[%s] ", data.ident)
    }
    return fmt.tprintf("%s%s\n", strings.to_string(buf), text)
}

ui_window_logger_console :: proc(open: ^bool) {
    if open^ == false {
        return
    }

    if ui_window("Console", open, .NoFocusOnAppearing | .AlwaysVerticalScrollbar) {
        ui_set_window_size_vec2({ f32(_e.platform.window_size.x), f32(_e.platform.window_size.y) }, .FirstUseEver)
        ui_set_window_pos_vec2({ 0, 0 }, .FirstUseEver)

        if _e.logger != nil {
            for line in _e.logger.lines {
                color := Color { 1, 1, 1, 1 }
                switch line.level {
                    case .Debug: { color = { 0.8, 0.8, 0.8, 1 } }
                    case .Info: { color = { 1, 1, 1, 1 } }
                    case .Warning: { color = { 0.8, 0.8, 0.2, 1 } }
                    case .Error: { color = { 0.8, 0.2, 0.2, 1 } }
                    case .Fatal: { color = { 1, 0.2, 0.2, 1 } }
                }
                ui_push_style_color(.Text, transmute([4]f32) color)
                ui_text(line.text)
                ui_pop_style_color(1)
            }
        }
    }
}
