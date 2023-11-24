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
    data:               log.File_Console_Logger_Data,

    arena:              mem.Arena,
    allocator:          runtime.Allocator,
    lines:              [dynamic]Logger_Line,
}

Logger_Line :: struct #packed {
    level:              log.Level,
    text:               string,
}

LOGGER_ARENA_SIZE :: mem.Megabyte * 1

@(private="package")
_logger: ^Logger_State

logger_init :: proc(allocator := context.allocator) -> (logger_state: ^Logger_State, ok: bool) #optional_ok {
    context.logger = log.create_console_logger(.Debug, { .Level, .Terminal_Color })

    log.infof("Logger -----------------------------------------------------")
    defer log_ok(ok)

    _logger = new(Logger_State, allocator)
    _logger.allocator = _make_logger_allocator(LOGGER_ARENA_SIZE, &_logger.arena, allocator)
    _logger.logger = context.logger
    _logger.lines = make([dynamic]Logger_Line, _logger.allocator)

    if IN_GAME_LOGGER {
        game_console_logger := log.Logger { _game_console_logger_proc, &_logger.data, .Debug, { .Level, .Terminal_Color, .Time } }
        _logger.logger = log.create_multi_logger(game_console_logger, _logger.logger)
    }

    log.infof("  IN_GAME_LOGGER:       %t", IN_GAME_LOGGER)

    logger_state = _logger
    ok = true
    return
}

logger_reload :: proc(logger_state: ^Logger_State) {
    assert(logger_state != nil)
    _logger = logger_state
}

@(private="package")
log_ok :: proc(ok: bool) {
    if ok {
        log.infof("  Init:                 OK")
    } else {
        log.warnf("  Init:                 KO")
    }
}

@(private="file")
_make_logger_allocator :: proc(size: int, arena: ^mem.Arena, allocator := context.allocator, loc := #caller_location) -> mem.Allocator {
    buffer, error := make([]u8, size, allocator)
    if error != .None {
        fmt.panicf("Buffer alloc error: %v.\n", error)
    }

    mem.arena_init(arena, buffer)
    arena_allocator := mem.arena_allocator(arena)
    arena_allocator.procedure = _logger_arena_allocator_proc

    return arena_allocator
}

@(private="file")
_logger_arena_allocator_proc :: proc(allocator_data: rawptr, mode: mem.Allocator_Mode, size, alignment: int, old_memory: rawptr, old_size: int, location := #caller_location) -> ([]byte, mem.Allocator_Error) {
    data, error := mem.arena_allocator_proc(allocator_data, mode, size, alignment, old_memory, old_size, location)

    if error == .Out_Of_Memory {
        _reset_logger_arena()
        return _logger_arena_allocator_proc(allocator_data, mode, size, alignment, old_memory, old_size)
    }

    return data, error
}

@(private="file")
_game_console_logger_proc :: proc(data: rawptr, level: log.Level, text: string, options: log.Options, location := #caller_location) {
    context.allocator = _logger.allocator

    text_clone := strings.clone(_string_logger_proc(data, level, text, options, location))
    line, line_err := new(Logger_Line, _logger.allocator)
    line.level = level
    line.text = text_clone
    append(&_logger.lines, line^)
}

@(private="file")
_reset_logger_arena :: proc() {
    mem.free_all(_logger.allocator)
    _logger.lines = make([dynamic]Logger_Line, _logger.allocator)
    log.warnf("Logger arena cleared (Out_Of_Memory).")
    return
}

@(private="file")
_string_logger_proc :: proc(logger_data: rawptr, level: log.Level, text: string, options: log.Options, location := #caller_location) -> string {
    context.allocator = _logger.allocator
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

    if ui_window("Console", open, .NoFocusOnAppearing | .AlwaysVerticalScrollbar | .NoSavedSettings) {
        ui_set_window_size_vec2({ f32(_e.platform.window_size.x), f32(_e.platform.window_size.y) }, .FirstUseEver)
        ui_set_window_pos_vec2({ 0, 0 }, .FirstUseEver)

        if _logger != nil {
            for line in _logger.lines {
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

        if ui_get_scroll_y() >= ui_get_scroll_max_y() {
            ui_set_scroll_here_y(1)
        }
    }
}
