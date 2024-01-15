package engine

import "core:fmt"
import "core:log"
import "core:mem"
import "core:os"
import "core:path/slashpath"
import "core:slice"
import "core:strings"
import "core:time"
import "../tools"

Asset_Id :: distinct u32

Assets_State :: struct {
    arena:              tools.Named_Virtual_Arena,
    assets:             [100]Asset,
    next_id:            Asset_Id,
    root_folder:        string,
    debug_ui_asset:     Asset_Id,
    externals:          [dynamic]Asset_External_Meta,
}

Asset :: struct {
    id:                 Asset_Id,
    file_name:          string,
    loaded_at:          time.Time,
    try_loaded_at:      time.Time,
    type:               Asset_Type,
    state:              Asset_States,
    info:               Asset_Info,
    file_changed_proc:  File_Watch_Callback_Proc,
    external_id:        int, // Index into Assets_State.externals
}

Asset_States :: enum {
    Unloaded,
    Queued,
    Loaded,
    Errored,
    Locked,
}

Asset_Type :: enum {
    Invalid,
    Image,
    Audio,
    Map,
    Shader,
    External,
}

Asset_External_Meta :: struct {
    load_proc:          proc "contextless" (full_path: string) -> (rawptr, bool),
    unload_proc:        rawptr,
    print_proc:         proc "contextless" (asset: rawptr) -> string
}

Asset_Info :: union {
    Asset_Info_Image,
    Asset_Info_Audio,
    Asset_Info_Map,
    Asset_Info_Shader,
    Asset_Info_External,
}
Asset_Info_Image    :: ^Texture
Asset_Info_Audio    :: ^Audio_Clip
Asset_Info_Map      :: ^LDTK_Root
Asset_Info_Shader   :: Shader
Asset_Info_External :: distinct rawptr

Asset_Load_Options :: union {
    Asset_Load_Options_Audio,
}
Asset_Load_Options_Audio :: struct {
    type: Audio_Clip_Types,
}

ASSETS_ARENA_SIZE :: mem.Megabyte

@(private="file")
_assets: ^Assets_State

asset_init :: proc() -> (asset_state: ^Assets_State, ok: bool) #optional_ok {
    profiler_zone("asset_init", PROFILER_COLOR_ENGINE)

    log.infof("Assets -----------------------------------------------------")
    defer log_ok(ok)

    _assets = tools.mem_named_arena_virtual_bootstrap_new_or_panic(Assets_State, "arena", ASSETS_ARENA_SIZE, "assets")
    context.allocator = _assets.arena.allocator

    root_directory := "."
    if len(os.args) > 0 {
        root_directory = slashpath.dir(os.args[0], context.temp_allocator)
    }
    _assets.root_folder = slashpath.join({ root_directory, "/", ASSETS_PATH })

    // Important so we can later assume that asset_id of 0 will be invalid
    asset := Asset {}
    asset.file_name = strings.clone("invalid_file_on_purpose")
    asset.state = .Errored
    _assets.assets[0] = asset
    _assets.next_id = Asset_Id(1)

    log.infof("  assets_max:           %v", len(_assets.assets))

    ok = true
    asset_state = _assets
    return
}

asset_reload :: proc(asset_state: ^Assets_State) {
    assert(asset_state != nil)
    _assets = asset_state
    log.infof("Unloading all shaders...")
    for asset in _assets.assets {
        if asset.type == .Shader {
            asset_unload(asset.id)
        }
    }
}

asset_register_external :: proc(meta: Asset_External_Meta) -> int {
    external_id := len(_assets.externals)
    append(&_assets.externals, meta)
    return external_id
}

asset_add :: proc(file_name: string, type: Asset_Type, file_changed_proc: File_Watch_Callback_Proc = nil, external_id: int = -1) -> Asset_Id {
    context.allocator = _assets.arena.allocator
    assert(_assets.assets[0].id == 0)

    asset := Asset {}
    asset.id = _assets.next_id
    asset.file_name = strings.clone(file_name)
    if external_id > -1 {
        assert(len(_assets.externals) > external_id, fmt.tprintf("external_id not registered: %v", external_id))
        asset.external_id = external_id
    }
    asset.type = type
    when HOT_RELOAD_ASSETS {
        asset.file_changed_proc = file_changed_proc
        file_watch_add(asset.id, _asset_file_changed)
    }
    _assets.assets[asset.id] = asset
    _assets.next_id = Asset_Id(int(_assets.next_id) + 1)

    return asset.id
}

@(private="file")
_asset_file_changed : File_Watch_Callback_Proc : proc(file_watch: ^File_Watch, file_info: ^os.File_Info) {
    context.allocator = _assets.arena.allocator
    asset := asset_get_by_asset_id(file_watch.asset_id)
    asset_unload(asset.id)
    asset_load(asset.id)
    log.debugf("[Asset] Asset reloaded: %v", file_info.name)
    ui_create_notification(fmt.aprintf("Asset reloaded: %v", file_info.name))
    if asset.file_changed_proc != nil {
        asset.file_changed_proc(file_watch, file_info)
    }
}

asset_get_full_path :: proc(asset: ^Asset) -> string {
    return slashpath.join({ _assets.root_folder, asset.file_name }, context.temp_allocator)
}

// TODO: Make this non blocking
asset_load :: proc(asset_id: Asset_Id, options: Asset_Load_Options = nil, loc := #caller_location) {
    context.allocator = _assets.arena.allocator
    asset := asset_get_by_asset_id(asset_id)

    if asset.state == .Queued || asset.state == .Loaded {
        log.debug("Asset already loaded: ", asset.file_name)
        return
    }

    asset.state = .Queued
    asset.try_loaded_at = time.now()
    full_path := asset_get_full_path(asset)
    // log.debugf("Asset loading: %i %v %v", asset.id, full_path, loc)
    // defer log.warnf("Asset loaded: %i %v", asset.id, full_path)

    switch asset.type {
        case .Image: {
            texture, ok := r_load_texture(full_path)
            if ok {
                asset.loaded_at = time.now()
                asset.state = .Loaded
                asset.info = cast(Asset_Info_Image) texture
                // log.infof("Image loaded: %v", full_path)
                return
            }
        }

        case .Audio: {
            if audio_is_enabled() == false {
                asset.state = .Errored
                return
            }

            load_options := Asset_Load_Options_Audio {}
            if options != nil {
                load_options = options.(Asset_Load_Options_Audio)
            }

            clip, ok := audio_load_clip(full_path, asset.id, load_options.type)
            if ok {
                asset.loaded_at = time.now()
                asset.state = .Loaded
                asset.info = cast(Asset_Info_Audio) clip
                // log.infof("Audio loaded: %v", full_path)
                return
            }
        }

        case .Map: {
            ldtk, ok := ldtk_load_file(full_path, _assets.arena.allocator)
            if ok {
                asset.loaded_at = time.now()
                asset.state = .Loaded
                asset.info = cast(Asset_Info_Map) ldtk
                // log.infof("Map loaded: %v", full_path)
                return
            }
        }

        case .Shader: {
            shader, ok := r_shader_create_from_asset(full_path, asset.id)
            if ok {
                asset.loaded_at = time.now()
                asset.state = .Loaded
                asset.info = cast(Asset_Info_Shader) shader
                // log.infof("Shader loaded: %v", full_path)
                return
            }
        }

        case .External: {
            if _assets.externals[asset.external_id].load_proc != nil {
                data, ok := _assets.externals[asset.external_id].load_proc(full_path)
                if ok {
                    asset.loaded_at = time.now()
                    asset.state = .Loaded
                    asset.info = cast(Asset_Info_External) data
                    // log.infof("External loaded: %v", full_path)
                    return
                }
            }
        }

        case .Invalid:
        case: {
            log.errorf("Asset type not handled: %v.", asset.type)
        }
    }

    asset.state = .Errored
    log.errorf("Asset couldn't be loaded: %v", full_path)
}

asset_unload :: proc(asset_id: Asset_Id, location := #caller_location) {
    // log.debugf("asset_unload: %v <- %v", asset_id, location)
    context.allocator = _assets.arena.allocator
    asset := &_assets.assets[asset_id]
    #partial switch &asset_info in asset.info {
        case Asset_Info_Audio: {
            audio_unload_clip(asset.id)
            asset_info = nil
        }

        case Asset_Info_Image: {
            asset_info = nil
        }

        case Asset_Info_Shader: {
            asset_info = {}
        }

        case: {
            log.errorf("Asset type not handled: %v.", asset.type)
        }
    }

    asset.state = .Unloaded
}

asset_get_all :: proc() -> []Asset {
    return _assets.assets[:]
}

asset_get :: proc {
    asset_get_by_asset_id,
    asset_get_by_file_name,
}
asset_get_by_asset_id :: proc(asset_id: Asset_Id) -> (^Asset, bool) #optional_ok {
    for asset, i in _assets.assets {
        if asset.id == asset_id {
            return &_assets.assets[i], true
        }
    }
    return nil, false
}
// TODO: Remove this?
asset_get_by_file_name :: proc(file_name: string) -> (^Asset, bool) {
    for asset, i in _assets.assets {
        if asset.file_name == file_name {
            return &_assets.assets[i], true
        }
    }
    return nil, false
}

asset_get_asset_info_shader :: proc(asset_id: Asset_Id, loc := #caller_location) -> (asset_info: Asset_Info_Shader, ok: bool) {
    if asset_id == Asset_Id(0) {
        // log.errorf("Can't get_asset_info on invalid asset (0) %v", loc)
        return
    }

    asset := asset_get_by_asset_id(asset_id)
    if asset.info == nil {
        return
    }

    asset_info = asset.info.(Asset_Info_Shader) or_return
    ok = true

    return
}
asset_get_asset_info_map :: proc(asset_id: Asset_Id, loc := #caller_location) -> (asset_info: Asset_Info_Map, ok: bool) {
    if asset_id == Asset_Id(0) {
        // log.warnf("Can't get_asset_info on invalid asset (0) %v", loc)
        return
    }

    asset := asset_get_by_asset_id(asset_id)
    if asset.info == nil {
        return
    }

    asset_info = asset.info.(Asset_Info_Map) or_return
    ok = true

    return
}
asset_get_asset_info_image :: proc(asset_id: Asset_Id, loc := #caller_location) -> (asset_info: Asset_Info_Image, ok: bool) {
    if asset_id == Asset_Id(0) {
        // log.warnf("Can't get_asset_info on invalid asset (0) %v", loc)
        return
    }

    asset := asset_get_by_asset_id(asset_id)
    if asset.info == nil {
        return
    }

    asset_info = asset.info.(Asset_Info_Image) or_return
    ok = true

    return
}
asset_get_asset_info_external :: proc(asset_id: Asset_Id, $type: typeid, loc := #caller_location) -> (result: ^type, ok: bool) {
    if asset_id == Asset_Id(0) {
        // log.warnf("Can't get_asset_info on invalid asset (0) %v", loc)
        return
    }

    asset := asset_get_by_asset_id(asset_id)
    if asset.info == nil {
        return
    }

    info, info_ok := asset.info.(Asset_Info_External)
    if info_ok {
        return cast(^type) info, true
    }

    return
}

ui_window_assets :: proc(open: ^bool) {
    if open^ == false {
        return
    }

    when IMGUI_ENABLE == false {
        return
    }

    context.allocator = context.temp_allocator
    if ui_window("Assets", open) {
        @(static) filter_type_invalid := false
        @(static) filter_type_image := true
        @(static) filter_type_audio := false
        @(static) filter_type_map := true
        @(static) filter_type_shader := true
        @(static) filter_type_external := false
        ui_checkbox("Invalid", &filter_type_invalid); ui_same_line()
        ui_checkbox("Image", &filter_type_image); ui_same_line()
        ui_checkbox("Audio", &filter_type_audio); ui_same_line()
        ui_checkbox("Map", &filter_type_map); ui_same_line()
        ui_checkbox("Shader", &filter_type_shader); ui_same_line()
        ui_checkbox("External", &filter_type_external);

        columns := []string { "id", "file_name", "type", "state", "info", "actions" }
        if ui_table(columns) {
            assets := asset_get_all()
            slice.sort_by(assets, sort_entries_by_id)
            sort_entries_by_id :: proc(a, b: Asset) -> bool {
                return a.id < b.id
            }

            for asset in assets {
                show_row := true
                if asset.type == .Invalid { show_row = filter_type_invalid }
                if asset.type == .Image { show_row = filter_type_image }
                if asset.type == .Audio { show_row = filter_type_audio }
                if asset.type == .Map { show_row = filter_type_map }
                if asset.type == .Shader { show_row = filter_type_shader }
                if asset.type == .External { show_row = filter_type_external }
                if show_row == false {
                    continue
                }

                ui_table_next_row()

                // asset, asset_found := asset_get_by_asset_id(asset_id)
                for column, i in columns {
                    ui_table_set_column_index(i32(i))
                    switch column {
                        case "id": ui_text("%v", asset.id)
                        case "state": ui_text("%v", asset.state)
                        case "type": ui_text("%v", asset.type)
                        case "file_name": {
                            if asset.state == .Errored { ui_push_style_color(.Text, { 1, 0.4, 0.4, 1 }) }
                            ui_text("%v", asset.file_name)
                            if asset.state == .Errored { ui_pop_style_color(1) }
                        }
                        case "info": {
                            if asset.state != .Loaded {
                                ui_text("-")
                                continue
                            }
                            switch asset_info in asset.info {
                                case Asset_Info_Image: {
                                    ui_text("renderer_id: %v, size: %v, channels_in_file: %v", asset_info.renderer_id.id, asset_info.size, asset_info.channels_in_file)
                                }
                                case Asset_Info_Audio: {
                                    ui_text("type: %v, clip: %v", asset_info.type, asset_info)
                                }
                                case Asset_Info_Map: {
                                    ui_text("version: %v, levels: %v", asset_info.jsonVersion, len(asset_info.levels))
                                }
                                case Asset_Info_Shader: {
                                    ui_text("renderer_id: %v", asset_info.id)
                                }
                                case Asset_Info_External: {
                                    external_meta := _assets.externals[asset.external_id]
                                    text := fmt.tprintf("rawptr: %v", asset_info)
                                    if external_meta.print_proc != nil {
                                        text = external_meta.print_proc(asset_info)
                                    }
                                    ui_text("%v", text)
                                }
                            }
                        }
                        case "actions": {
                            ui_push_id(i32(asset.id))
                            if ui_button("Load") {
                                asset_load(asset.id)
                            }
                            ui_same_line()
                            if asset.state == .Loaded && ui_button("Unload") {
                                asset_unload(asset.id)
                            }
                            ui_pop_id()
                        }
                        case: ui_text("x")
                    }
                }
            }
        }
    }
}
