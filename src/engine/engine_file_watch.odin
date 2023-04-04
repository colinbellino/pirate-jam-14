package engine

import "core:fmt"
import "core:os"
import "core:time"
import "core:log"
import "core:strings"

File_Watch :: struct {
    file_path:          string,
    callback_proc:      File_Watch_Callback_Proc,
    last_change_proc:   File_Watch_Last_Change_Proc,
}

File_Watch_Callback_Proc :: #type proc(file_watch: ^File_Watch, file_info: ^os.File_Info, app: ^App)
File_Watch_Last_Change_Proc :: #type proc(app: ^App) -> time.Time

file_watch_add :: proc(app: ^App, file_path: string, callback_proc: File_Watch_Callback_Proc, last_change_proc: File_Watch_Last_Change_Proc) {
    if app.debug_state.file_watches_count == len(app.debug_state.file_watches) {
        log.error("Max file watch reached.");
        return;
    }

    app.debug_state.file_watches[app.debug_state.file_watches_count] = File_Watch {
        strings.clone(file_path, app.debug_allocator),
        callback_proc,
        last_change_proc,
    };
    // log.debugf("file_watch_add: %v", app.debug_state.file_watches[app.debug_state.file_watches_count]);
    app.debug_state.file_watches_count += 1;
}

file_watch_update :: proc(app: ^App) {
    for i in 0 ..< app.debug_state.file_watches_count {
        file_watch := &app.debug_state.file_watches[i];
        file_info, info_err := os.stat(file_watch.file_path, context.temp_allocator);
        if info_err == 0 && time.diff(file_watch.last_change_proc(app), file_info.modification_time) > 0 {
            file_watch.callback_proc(file_watch, &file_info, app);
        }
    }
}
