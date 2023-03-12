package engine

import "core:fmt"
import "core:log"
import "core:mem"
import "core:os"
import "core:runtime"
import "core:strings"
import "core:time"

Logger_State :: struct {
    allocator:          mem.Allocator,
    logger:             runtime.Logger,
    buffer_updated:     bool,
    lines:              [dynamic]Line,
}

Line :: struct {
    level:              log.Level,
    text:               string,
}

_state: ^Logger_State;

logger_create :: proc(allocator: mem.Allocator) -> (state: ^Logger_State) {
    context.allocator = allocator;
    state = new(Logger_State);
    state.allocator = allocator;
    // options := log.Options { .Level, .Time, .Short_File_Path, .Line, .Terminal_Color };
    options := log.Options { .Time };
    data := new(log.File_Console_Logger_Data);
    data.file_handle = os.INVALID_HANDLE;
    data.ident = "";
    state.logger = log.Logger { logger_proc, data, runtime.Logger_Level.Debug, options };
    _state = state;

    return;
}

logger_proc :: proc(logger_data: rawptr, level: log.Level, text: string, options: log.Options, location := #caller_location) {
    context.allocator = _state.allocator;

    content := strings.clone(_string_logger_proc(logger_data, level, text, options, location));
    append(&_state.lines, Line { level, content });
    _state.buffer_updated = true;
}

logger_allocator_proc :: proc(
    allocator_data: rawptr, mode: mem.Allocator_Mode,
    size, alignment: int,
    old_memory: rawptr, old_size: int, location := #caller_location,
) -> (result: []byte, error: mem.Allocator_Error) {
    result, error = runtime.default_allocator_proc(allocator_data, mode, size, alignment, old_memory, old_size, location);

    if contains_os_args("log-alloc-logger") {
        fmt.printf("[LOGGER] %v %v byte at %v\n", mode, size, location);
    }

    if error != .None {
        fmt.eprintf("[LOGGER] alloc error %v\n", error);
        os.exit(0);
    }
    return;
}

@(private="file")
_string_logger_proc :: proc(logger_data: rawptr, level: log.Level, text: string, options: log.Options, location := #caller_location) -> string {
    context.allocator = _state.allocator;

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
