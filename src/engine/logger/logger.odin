package logger

import "core:fmt"
import "core:log"
import "core:os"
import "core:runtime"
import "core:strings"
import "core:time"

State :: struct {
    log_buf_updated:    bool,
    lines:              [dynamic]Line,
}

Line :: struct {
    level:              log.Level,
    text:               string,
}

state := State {};

create_logger :: proc() -> runtime.Logger {
    options := log.Options { .Level, .Time, .Short_File_Path, .Line, .Terminal_Color };
    logger := log.create_console_logger(runtime.Logger_Level.Debug, options);
    logger.procedure = logger_proc;
    return logger;
}

logger_proc :: proc(logger_data: rawptr, level: log.Level, text: string, options: log.Options, location := #caller_location) {
    ui_options := log.Options { .Time };
    fmt.print(string_logger_proc(logger_data, level, text, options, location));
    write_line(level, string_logger_proc(logger_data, level, text, ui_options, location));
}

string_logger_proc :: proc(logger_data: rawptr, level: log.Level, text: string, options: log.Options, location := #caller_location) -> string {
    using log;
    data := cast(^File_Console_Logger_Data)logger_data
    h: os.Handle = os.stdout if level <= Level.Error else os.stderr
    if data.file_handle != os.INVALID_HANDLE {
        h = data.file_handle
    }
    backing: [1024]byte //NOTE(Hoej): 1024 might be too much for a header backing, unless somebody has really long paths.
    buf := strings.builder_from_bytes(backing[:])

    do_level_header(options, level, &buf)

    when time.IS_SUPPORTED {
        if Full_Timestamp_Opts & options != nil {
            fmt.sbprint(&buf, "[")
            t := time.now()
            y, m, d := time.date(t)
            h, min, s := time.clock(t)
            if .Date in options { fmt.sbprintf(&buf, "%d-%02d-%02d ", y, m, d)    }
            if .Time in options { fmt.sbprintf(&buf, "%02d:%02d:%02d", h, min, s) }
            fmt.sbprint(&buf, "] ")
        }
    }

    do_location_header(options, &buf, location)

    if .Thread_Id in options {
        // NOTE(Oskar): not using context.thread_id here since that could be
        // incorrect when replacing context for a thread.
        fmt.sbprintf(&buf, "[{}] ", os.current_thread_id())
    }

    if data.ident != "" {
        fmt.sbprintf(&buf, "[%s] ", data.ident)
    }
    //TODO(Hoej): When we have better atomics and such, make this thread-safe
    return fmt.tprintf("%s%s\n", strings.to_string(buf), text)
}

write_line :: proc(level: log.Level, text: string) {
    state.log_buf_updated = true;
    append(&state.lines, Line { level, text });
}

read_all_lines :: proc() -> [dynamic]Line {
    return state.lines;
}

reset :: proc() {
    delete(state.lines);
    state.log_buf_updated = true;
}
