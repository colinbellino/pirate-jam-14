package engine

import "core:log"
import "core:os"
import "core:path/slashpath"
import "core:strings"
import "core:time"

Asset_Id :: distinct u32

Assets_State :: struct {
    // allocator:          runtime.Allocator,
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
    size:    Vector2i,
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

asset_init :: proc() -> (ok: bool) {
    profiler_zone("asset_init")
    context.allocator = _engine.main_allocator

    _engine.assets = new(Assets_State)
    _engine.assets.assets = make([]Asset, 200)
    root_directory := "."
    if len(os.args) > 0 {
        root_directory = slashpath.dir(os.args[0], context.temp_allocator)
    }
    _engine.assets.root_folder = slashpath.join({ root_directory, "/", ASSETS_PATH })

    // Important so we can later assume that asset_id of 0 will be invalid
    asset := Asset {}
    asset.file_name = strings.clone("invalid_file_on_purpose")
    asset.state = .Errored
    _engine.assets.assets[asset.id] = asset
    _engine.assets.assets_count += 1

    ok = true
    return
}

asset_add :: proc(file_name: string, type: Asset_Type, file_changed_proc: File_Watch_Callback_Proc = nil) -> Asset_Id {
    context.allocator = _engine.main_allocator
    assert(_engine.assets.assets[0].id == 0)

    asset := Asset {}
    asset.id = Asset_Id(_engine.assets.assets_count)
    asset.file_name = strings.clone(file_name)
    asset.type = type
    if HOT_RELOAD_ASSETS {
        asset.file_changed_proc = file_changed_proc
        file_watch_add(asset.id, _asset_file_changed)
    }
    _engine.assets.assets[asset.id] = asset
    _engine.assets.assets_count += 1

    return asset.id
}

_asset_file_changed : File_Watch_Callback_Proc : proc(file_watch: ^File_Watch, file_info: ^os.File_Info) {
    asset := &_engine.assets.assets[file_watch.asset_id]
    asset_unload(asset.id)
    asset_load(asset.id)
    // log.debugf("[Asset] File changed: %v", asset)
    if asset.file_changed_proc != nil {
        asset.file_changed_proc(file_watch, file_info)
    }
}

asset_get_full_path :: proc(state: ^Assets_State, asset: ^Asset) -> string {
    if asset.type == .Code {
        return asset.file_name
    }
    return slashpath.join({ state.root_folder, asset.file_name }, context.temp_allocator)
}

// TODO: Make this non blocking
asset_load :: proc(asset_id: Asset_Id) {
    context.allocator = _engine.main_allocator
    asset := &_engine.assets.assets[asset_id]

    if asset.state == .Queued || asset.state == .Loaded {
        log.debug("Asset already loaded: ", asset.file_name)
        return
    }

    asset.state = .Queued
    full_path := asset_get_full_path(_engine.assets, asset)
    // log.warnf("Asset loading: %i %v", asset.id, full_path)
    // defer log.warnf("Asset loaded: %i %v", asset.id, full_path)

    switch asset.type {
        case .Code: {
            log.error("No!")
            // ok := game_code_load(full_path, _engine)
            // if ok {
            //     asset.loaded_at = time.now()
            //     asset.state = .Loaded

            //     // Create the next game code to check for, this is hacky and we probably want to remove later
            //     next_code_file_name := fmt.tprintf("game%i.bin", _engine.debug.game_counter)
            //     next_code_asset_id := asset_add(next_code_file_name, .Code)

            //     file_watch_remove(asset_id)

            //     return
            // }
        }

        case .Image: {
            texture_index, texture, ok := load_texture_from_image_path(full_path)
            if ok {
                asset.loaded_at = time.now()
                asset.state = .Loaded
                width, height: i32
                renderer_query_texture(texture, &width, &height)
                asset.info = Asset_Info_Image { texture, { width, height } }
                // log.infof("Image loaded: %v", full_path)
                return
            }
        }
        case .Sound: {

        }
        case .Map: {
            ldtk, ok := ldtk_load_file(full_path)
            if ok {
                asset.loaded_at = time.now()
                asset.state = .Loaded
                asset.info = Asset_Info_Map { ldtk }
                log.infof("Map loaded: %v", full_path)
                return
            }
        }
    }

    asset.state = .Errored
    log.errorf("Asset not loaded: %v", full_path)
}

asset_unload :: proc(asset_id: Asset_Id) {
    context.allocator = _engine.main_allocator

    asset := &_engine.assets.assets[asset_id]
    // switch asset.type {
    //     case .Image: {
    //         // FIXME: our arena allocator can't really free right now.
    //     }
    //     case .Sound: {

    //     }
    //     case .Map: {
    //         info := asset.info.(Asset_Info_Map)
    //         // free(info.ldtk)
    //         // free(&info)
    //         // FIXME: our arena allocator can't really free right now.
    //         log.debug(asset)
    //     }
    // }

    asset.state = .Unloaded
}

asset_get_by_file_name :: proc(state: ^Assets_State, file_name: string) -> (^Asset, bool) {
    for i := 0; i < state.assets_count; i += 1 {
        if state.assets[i].file_name == file_name {
            return &state.assets[i], true
        }
    }
    return nil, false
}

@(private="file")
load_texture_from_image_path :: proc(path: string, allocator := context.allocator) -> (texture_index : int = -1, texture: ^Texture, ok: bool) {
    context.allocator = allocator

    surface : ^Surface
    surface, ok = platform_load_surface_from_image_file(path, allocator)
    defer platform_free_surface(surface)

    if ok == false {
        log.error("Texture not loaded (load_surface_from_image_file).")
        return
    }

    texture, texture_index, ok = renderer_create_texture_from_surface(surface)
    if ok == false {
        log.error("Texture not loaded (renderer_create_texture_from_surface).")
        return
    }

    return
}
