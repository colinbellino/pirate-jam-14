package logger

import "core:fmt"
import "core:strings"
import "core:log"
import "core:runtime"

State :: struct {
    log_buf:            [1<<16]byte,
    log_buf_len:        int,
    log_buf_updated:    bool,
    logger:             runtime.Logger,
}

state := State {};

create_logger :: proc() -> runtime.Logger {
    options := log.Options { /* .Level, */ /* .Date, */ .Time, .Short_File_Path, .Line, .Terminal_Color };
    state.logger = log.create_console_logger(runtime.Logger_Level.Debug, options);
    return state.logger;
}

destroy_logger :: proc() {
    log.destroy_console_logger(state.logger);
}

write_log :: proc(value: string, args: ..any) {
    str := fmt.tprintf(value, ..args);
    log.debug(str);

    state.log_buf_len += copy(state.log_buf[state.log_buf_len:], str);
    state.log_buf_len += copy(state.log_buf[state.log_buf_len:], "\n");
    state.log_buf_updated = true;
}

read_log :: proc() -> string {
    return string(state.log_buf[:state.log_buf_len]);
}

reset_log :: proc() {
    state.log_buf_updated = true;
    state.log_buf_len = 0;
}
