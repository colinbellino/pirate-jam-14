package engine

import "core:os"
import "core:time"
import "core:log"
import "core:strings"

File_Watch :: struct {
    asset_id:              Asset_Id,
    callback_proc:      File_Watch_Callback_Proc,
    // file_path:          string,
    // last_change_proc:   File_Watch_Last_Change_Proc,
}

File_Watch_Callback_Proc :: #type proc(file_watch: ^File_Watch, file_info: ^os.File_Info, app: ^App)
File_Watch_Last_Change_Proc :: #type proc(app: ^App) -> time.Time

file_watch_add :: proc(app: ^App, asset_id: Asset_Id, callback_proc: File_Watch_Callback_Proc) {
    if app.debug_state.file_watches_count == len(app.debug_state.file_watches) {
        log.error("Max file watch reached.");
        return;
    }

    file_watch := File_Watch { asset_id, callback_proc };
    app.debug_state.file_watches[app.debug_state.file_watches_count] = file_watch;
    // log.debugf("file_watch_add: %v", app.debug_state.file_watches[app.debug_state.file_watches_count]);
    app.debug_state.file_watches_count += 1;
}

file_watch_remove :: proc(app: ^App, asset_id: Asset_Id) {
    for i := 0; i < app.debug_state.file_watches_count; i += 1 {
        file_watch := &app.debug_state.file_watches[i];
        if file_watch.asset_id == asset_id {
            file_watch^ = {};
        }
    }
}

file_watch_update :: proc(app: ^App) {
    for i in 0 ..< app.debug_state.file_watches_count {
        file_watch := &app.debug_state.file_watches[i];
        if file_watch.asset_id == 0 {
            continue;
        }

        asset := &app.assets.assets[file_watch.asset_id];
        if asset.state != .Loaded {
            continue;
        }

        file_info, info_err := os.stat(asset_get_full_path(app.assets, asset), context.temp_allocator);
        if info_err == 0 && time.diff(asset.loaded_at, file_info.modification_time) > 0 {
            file_watch.callback_proc(file_watch, &file_info, app);
        }
    }
}
