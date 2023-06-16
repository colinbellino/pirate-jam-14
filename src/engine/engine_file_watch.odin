package engine

import "core:os"
import "core:time"
import "core:log"
import "core:strings"

File_Watch :: struct {
    asset_id:       Asset_Id,
    callback_proc:  File_Watch_Callback_Proc,
}

File_Watch_Callback_Proc :: #type proc(file_watch: ^File_Watch, file_info: ^os.File_Info)
File_Watch_Last_Change_Proc :: #type proc() -> time.Time

file_watch_add :: proc(asset_id: Asset_Id, callback_proc: File_Watch_Callback_Proc) {
    if _app.debug.file_watches_count == len(_app.debug.file_watches) {
        log.error("Max file watch reached.");
        return;
    }

    file_watch := File_Watch { asset_id, callback_proc };
    _app.debug.file_watches[_app.debug.file_watches_count] = file_watch;
    _app.debug.file_watches_count += 1;
}

file_watch_remove :: proc(asset_id: Asset_Id) {
    for i := 0; i < _app.debug.file_watches_count; i += 1 {
        file_watch := &_app.debug.file_watches[i];
        if file_watch.asset_id == asset_id {
            file_watch^ = {};
        }
    }
}

file_watch_update :: proc() {
    for i in 0 ..< _app.debug.file_watches_count {
        file_watch := &_app.debug.file_watches[i];
        if file_watch.asset_id == 0 {
            continue;
        }

        asset := &_app.assets.assets[file_watch.asset_id];
        // if asset.state != .Loaded {
        //     continue;
        // }

        full_path := asset_get_full_path(_app.assets, asset);
        file_info, info_err := os.stat(full_path, context.temp_allocator);
        if info_err == 0 && time.diff(asset.loaded_at, file_info.modification_time) > 0 {
            file_watch.callback_proc(file_watch, &file_info);
        }
    }
}
