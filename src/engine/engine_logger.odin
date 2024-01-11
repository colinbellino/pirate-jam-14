package engine

import "core:fmt"
import "core:log"
import "core:mem"
import "core:os"
import "core:runtime"
import "core:strings"
import "core:time"
import "../tools"

Logger_State :: struct {
    arena:              tools.Named_Virtual_Arena,
    internal_arena:     tools.Named_Virtual_Arena,
    logger:             runtime.Logger,
    data:               log.File_Console_Logger_Data,
    auto_scroll:        bool,
    lines:              [dynamic]Logger_Line,
}

Logger_Line :: struct #packed {
    level:              log.Level,
    text:               string,
}

LOGGER_ARENA_SIZE :: 8 * mem.Megabyte

@(private="file")
_logger: ^Logger_State

logger_init :: proc() -> (logger_state: ^Logger_State, ok: bool) #optional_ok {
    _logger = tools.mem_named_arena_virtual_bootstrap_new_or_panic(Logger_State, "arena", mem.Kilobyte, "logger")
    tools.mem_make_named_arena(&_logger.internal_arena, "logger_internal", LOGGER_ARENA_SIZE)
    _logger.internal_arena.allocator.procedure = logger_allocator_proc
    context.allocator = _logger.arena.allocator

    _logger.logger = log.nil_logger()
    when LOGGER_ENABLE {
        _logger.logger = log.create_console_logger(.Debug, { .Level, .Terminal_Color })
    }
    context.logger = _logger.logger

    log.infof("Logger -----------------------------------------------------")
    defer log_ok(ok)

    when IN_GAME_LOGGER {
        game_console_logger := log.Logger { _game_console_logger_proc, &_logger.data, .Debug, { .Level, .Terminal_Color, .Time } }
        _logger.logger = log.create_multi_logger(game_console_logger, _logger.logger)
    }

    context.allocator = _logger.internal_arena.allocator
    _logger.auto_scroll = true
    _logger.lines = make([dynamic]Logger_Line)

    log.infof("  IN_GAME_LOGGER:       %t", IN_GAME_LOGGER)

    logger_state = _logger
    ok = true
    return
}

logger_get_logger :: proc() -> log.Logger {
    return _logger != nil ? _logger.logger : log.nil_logger()
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
logger_allocator_proc :: proc(allocator_data: rawptr, mode: mem.Allocator_Mode, size, alignment: int, old_memory: rawptr, old_size: int, location := #caller_location) -> ([]byte, mem.Allocator_Error) {
    named_arena := cast(^tools.Named_Virtual_Arena) allocator_data
    arena := cast(^mem.Arena) named_arena.backing_allocator.data

    data, error := named_arena.backing_allocator.procedure(arena, mode, size, alignment, old_memory, old_size, location)

    if error == .Out_Of_Memory {
        _reset_logger_arena()
        return logger_allocator_proc(allocator_data, mode, size, alignment, old_memory, old_size)
    }

    return data, error
}

@(private="file")
_game_console_logger_proc :: proc(data: rawptr, level: log.Level, text: string, options: log.Options, location := #caller_location) {
    context.allocator = _logger.internal_arena.allocator

    text_clone, text_clone_err := strings.clone(string_logger_proc(data, level, text, options, location))
    line, line_err := new(Logger_Line)
    line.level = level
    line.text = text_clone
    append(&_logger.lines, line^)

    string_logger_proc :: proc(logger_data: rawptr, level: log.Level, text: string, options: log.Options, location := #caller_location) -> string {
        context.allocator = _logger.internal_arena.allocator
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
}

@(private="file")
_reset_logger_arena :: proc() {
    mem.free_all(_logger.internal_arena.allocator)
    _logger.lines = make([dynamic]Logger_Line, _logger.internal_arena.allocator)
    log.warnf("Logger arena cleared (Out_Of_Memory).")
    return
}

ui_window_logger_console :: proc(open: ^bool) {
    if open^ == false {
        return
    }

    if ui_window("Console", open, .NoFocusOnAppearing | .AlwaysVerticalScrollbar | .NoSavedSettings | .MenuBar) {
        window_size := get_window_size()
        ui_set_window_size_vec2({ f32(window_size.x), f32(window_size.y) }, .FirstUseEver)
        ui_set_window_pos_vec2({ 0, 0 }, .FirstUseEver)

        if ui_menu_bar() {
            ui_menu_item_bool_ptr("Auto scroll", "", &_logger.auto_scroll, true)
        }

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

        if _logger.auto_scroll /* && ui_get_scroll_y() >= ui_get_scroll_max_y() */ {
            ui_set_scroll_here_y(1)
        }
    }
}
