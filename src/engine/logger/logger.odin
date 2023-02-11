package logger

import "core:fmt"

Log :: struct {
    log_buf:            [1<<16]byte,
    log_buf_len:        int,
    log_buf_updated:    bool,
}

write_log :: proc(str: string, log: ^Log) {
    fmt.println(str);
    log.log_buf_len += copy(log.log_buf[log.log_buf_len:], str);
    log.log_buf_len += copy(log.log_buf[log.log_buf_len:], "\n");
    log.log_buf_updated = true;
}

read_log :: proc(log: ^Log) -> string {
    return string(log.log_buf[:log.log_buf_len]);
}

reset_log :: proc(log: ^Log) {
    log.log_buf_updated = true;
    log.log_buf_len = 0;
}
