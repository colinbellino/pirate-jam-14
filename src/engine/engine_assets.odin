package engine

import "core:fmt"
import "core:log"
import "core:os"
import "core:path/slashpath"
import "core:runtime"
import "core:strings"
import "core:time"

Asset_Id :: distinct u32;

Assets :: struct {
    allocator:          runtime.Allocator,
    assets:             []Asset,
    assets_count:       int,
    root_folder:        string,
}

Asset :: struct {
    id:                 Asset_Id,
    file_name:          string,
    loaded_at:          time.Time,
    type:               Asset_Type,
    state:              Asset_State,
    info:               Asset_Info,
    file_changed_proc:  File_Watch_Callback_Proc,
}

Asset_Info :: union {
    Asset_Info_Image,
    Asset_Info_Sound,
    Asset_Info_Map,
}

Asset_Info_Image :: struct {
    texture: ^Texture,
}
Asset_Info_Sound :: struct { }
Asset_Info_Map :: struct {
    ldtk:   ^LDTK_Root,
}

Asset_Type :: enum {
    Code,
    Image,
    Sound,
    Map,
}

Asset_State :: enum {
    Unloaded,
    Queued,
    Loaded,
    Errored,
    Locked,
}

asset_init :: proc(app: ^App) {
    assets_state := app.assets;

    // Important so we can later assume that asset_id of 0 will be invalid
    asset := Asset {};
    asset.file_name = strings.clone("invalid_file_on_purpose", assets_state.allocator);
    asset.state = .Errored;
    assets_state.assets[asset.id] = asset;
    assets_state.assets_count += 1;
}

asset_add :: proc(app: ^App, file_name: string, type: Asset_Type, file_changed_proc: File_Watch_Callback_Proc = nil) -> Asset_Id {
    assets_state := app.assets;
    assert(assets_state.assets[0].id == 0);

    asset := Asset {};
    asset.id = Asset_Id(assets_state.assets_count);
    asset.file_name = strings.clone(file_name, assets_state.allocator);
    asset.type = type;
    if app.config.HOT_RELOAD_ASSETS {
        asset.file_changed_proc = file_changed_proc;
        file_watch_add(app, asset.id, _asset_file_changed);
    }
    assets_state.assets[asset.id] = asset;
    assets_state.assets_count += 1;

    return asset.id;
}

_asset_file_changed : File_Watch_Callback_Proc : proc(file_watch: ^File_Watch, file_info: ^os.File_Info, app: ^App) {
    asset := &app.assets.assets[file_watch.asset_id];
    asset_unload(app, asset.id);
    asset_load(app, asset.id);
    log.debugf("[Asset] File changed: %v", asset);
    if asset.file_changed_proc != nil {
        asset.file_changed_proc(file_watch, file_info, app);
    }
}

asset_get_full_path :: proc(state: ^Assets, asset: ^Asset) -> string {
    if asset.type == .Code {
        return asset.file_name;
    }
    return slashpath.join({ state.root_folder, asset.file_name }, context.temp_allocator);
}

// TODO: Make this non blocking
asset_load :: proc(app: ^App, asset_id: Asset_Id) {
    assets_state := app.assets;
    context.allocator = assets_state.allocator;

    asset := &assets_state.assets[asset_id];

    if asset.state == .Queued || asset.state == .Loaded {
        log.debug("Asset already loaded: ", asset);
        return;
    }

    asset.state = .Queued;
    full_path := slashpath.join({ assets_state.root_folder, asset.file_name }, context.temp_allocator);

    switch asset.type {
        case .Code: {
            ok := game_code_load(asset_get_full_path(assets_state, asset), app);
            if ok {
                log.debug("Game reloaded!");
                asset.loaded_at = time.now();
                asset.state = .Loaded;

                // Create the next game code to check for, this is hacky and we probably want to remove later
                next_code_file_name := fmt.tprintf("game%i.bin", _game_counter);
                next_code_asset_id := asset_add(app, next_code_file_name, .Code);
                next_code_asset := &assets_state.assets[next_code_asset_id];
                next_code_asset.state = .Loaded;

                file_watch_remove(app, asset_id);
                app.debug_state.start_game = true;

                return;
            }
        }

        case .Image: {
            texture_index, texture, ok := load_texture_from_image_path(full_path, app.renderer_state);
            if ok {
                asset.loaded_at = time.now();
                asset.state = .Loaded;
                asset.info = Asset_Info_Image { texture };
                log.infof("Image loaded: %v", full_path);
                return;
            }
        }
        case .Sound: {

        }
        case .Map: {
            ldtk, ok := ldtk_load_file(full_path);
            if ok {
                asset.loaded_at = time.now();
                asset.state = .Loaded;
                asset.info = Asset_Info_Map { ldtk };
                log.infof("Map loaded: %v", full_path);
                return;
            }
        }
    }

    asset.state = .Errored;
    log.errorf("Asset not loaded: %v", full_path);
}

asset_unload :: proc(app: ^App, asset_id: Asset_Id) {
    assets_state := app.assets;
    context.allocator = assets_state.allocator;

    asset := &assets_state.assets[asset_id];
    // switch asset.type {
    //     case .Image: {
    //         // FIXME: our arena allocator can't really free right now.
    //     }
    //     case .Sound: {

    //     }
    //     case .Map: {
    //         info := asset.info.(Asset_Info_Map);
    //         // free(info.ldtk);
    //         // free(&info);
    //         // FIXME: our arena allocator can't really free right now.
    //         log.debug(asset);
    //     }
    // }

    asset.state = .Unloaded;
}

asset_get_by_file_name :: proc(state: ^Assets, file_name: string) -> (^Asset, bool) {
    for i := 0; i < state.assets_count; i += 1 {
        if state.assets[i].file_name == file_name {
            return &state.assets[i], true;
        }
    }
    return nil, false;
}

@(private="file")
load_texture_from_image_path :: proc(path: string, renderer_state: ^Renderer_State, allocator := context.allocator) -> (texture_index : int = -1, texture: ^Texture, ok: bool) {
    context.allocator = allocator;

    surface : ^Surface;
    surface, ok = load_surface_from_image_file(path, allocator);
    defer free_surface(surface);

    if ok == false {
        log.error("Texture not loaded (load_surface_from_image_file).");
        return;
    }

    texture, texture_index, ok = create_texture_from_surface(renderer_state, surface);
    if ok == false {
        log.error("Texture not loaded (create_texture_from_surface).");
        return;
    }

    return;
}
