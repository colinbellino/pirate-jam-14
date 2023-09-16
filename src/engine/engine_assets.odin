package engine

import "core:log"
import "core:os"
import "core:path/slashpath"
import "core:strings"
import "core:time"
import "core:fmt"

Asset_Id :: distinct u32

Assets_State :: struct {
    // allocator:          runtime.Allocator,
    assets:             []Asset,
    assets_count:       int,
    root_folder:        string,
    debug_ui_asset:     Asset_Id,
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
    Asset_Info_Shader,
}

Asset_Info_Image :: struct {
    texture: ^Texture,
}
Asset_Info_Sound :: struct { }
Asset_Info_Map :: struct {
    ldtk:   ^LDTK_Root,
}
Asset_Info_Shader :: struct {
    shader:   ^Shader,
}

Asset_Load_Options :: union {
    Image_Load_Options,
}

Image_Load_Options :: struct {
    filter: i32, // TODO: use Renderer_Filter enum
    wrap: i32,   // TODO: use Renderer_Wrap enum
}

Asset_Type :: enum {
    Invalid,
    Code,
    Image,
    Sound,
    Map,
    Shader,
}

Asset_State :: enum {
    Unloaded,
    Queued,
    Loaded,
    Errored,
    Locked,
}

asset_init :: proc() -> (ok: bool) {
    profiler_zone("asset_init", PROFILER_COLOR_ENGINE)
    context.allocator = _e.allocator

    _e.assets = new(Assets_State)
    _e.assets.assets = make([]Asset, 200)
    root_directory := "."
    if len(os.args) > 0 {
        root_directory = slashpath.dir(os.args[0], context.temp_allocator)
    }
    _e.assets.root_folder = slashpath.join({ root_directory, "/", ASSETS_PATH })

    // Important so we can later assume that asset_id of 0 will be invalid
    asset := Asset {}
    asset.file_name = strings.clone("invalid_file_on_purpose")
    asset.state = .Errored
    _e.assets.assets[asset.id] = asset
    _e.assets.assets_count += 1

    ok = true
    return
}

asset_add :: proc(file_name: string, type: Asset_Type, file_changed_proc: File_Watch_Callback_Proc = nil) -> Asset_Id {
    context.allocator = _e.allocator
    assert(_e.assets.assets[0].id == 0)

    asset := Asset {}
    asset.id = Asset_Id(_e.assets.assets_count)
    asset.file_name = strings.clone(file_name)
    asset.type = type
    if HOT_RELOAD_ASSETS {
        asset.file_changed_proc = file_changed_proc
        file_watch_add(asset.id, _asset_file_changed)
    }
    _e.assets.assets[asset.id] = asset
    _e.assets.assets_count += 1

    return asset.id
}

_asset_file_changed : File_Watch_Callback_Proc : proc(file_watch: ^File_Watch, file_info: ^os.File_Info) {
    asset := &_e.assets.assets[file_watch.asset_id]
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
asset_load :: proc(asset_id: Asset_Id, options: Asset_Load_Options = nil) {
    context.allocator = _e.allocator
    asset := &_e.assets.assets[asset_id]

    if asset.state == .Queued || asset.state == .Loaded {
        log.debug("Asset already loaded: ", asset.file_name)
        return
    }

    asset.state = .Queued
    full_path := asset_get_full_path(_e.assets, asset)
    // log.warnf("Asset loading: %i %v", asset.id, full_path)
    // defer log.warnf("Asset loaded: %i %v", asset.id, full_path)

    #partial switch asset.type {
        case .Image: {
            assert(renderer_is_enabled(), "Renderer not enabled.")
            load_options := Image_Load_Options { RENDERER_FILTER_LINEAR, RENDERER_CLAMP_TO_EDGE }

            if options != nil {
                load_options = options.(Image_Load_Options)
            }

            texture, ok := renderer_load_texture(full_path, &load_options)
            if ok {
                asset.loaded_at = time.now()
                asset.state = .Loaded
                asset.info = Asset_Info_Image { texture }
                // log.infof("Image loaded: %v", full_path)
                return
            }
        }

        case .Map: {
            ldtk, ok := ldtk_load_file(full_path)
            if ok {
                asset.loaded_at = time.now()
                asset.state = .Loaded
                asset.info = Asset_Info_Map { ldtk }
                // log.infof("Map loaded: %v", full_path)
                return
            }
        }

        case .Shader: {
            shader, ok := renderer_shader_create(full_path, asset.id)
            if ok {
                asset.loaded_at = time.now()
                asset.state = .Loaded
                asset.info = Asset_Info_Shader { shader }
                log.infof("Shader loaded: %v", full_path)
                return
            }
        }

        case: {
            log.errorf("Asset type not handled: %v.", asset.type)
        }
    }

    asset.state = .Errored
    log.errorf("Asset not loaded: %v", full_path)
}

asset_unload :: proc(asset_id: Asset_Id) {
    context.allocator = _e.allocator

    asset := &_e.assets.assets[asset_id]
    #partial switch asset.type {
        case .Shader: {
            asset_info := &asset.info.(Asset_Info_Shader)
            asset_info.shader = nil
            renderer_shader_delete(asset.id)
        }

        case: {
            log.errorf("Asset type not handled: %v.", asset.type)
        }
    }

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

ui_debug_window_assets :: proc(open: ^bool) {
    when IMGUI_ENABLE && ODIN_DEBUG {
        if open^ == false {
            return
        }

        if ui_window("Assets", open) {
            columns := [?]string { "id", "file_name", "type", "state", "info", "actions" }
            if ui_begin_table("table1", len(columns), .RowBg | .SizingStretchSame | .Resizable) {

                ui_table_next_row(.Headers)
                for column, i in columns {
                    ui_table_set_column_index(i32(i))
                    ui_text(column)
                }

                for i := 0; i < _e.assets.assets_count; i += 1 {
                    asset := &_e.assets.assets[i]
                    ui_table_next_row()

                    for column, i in columns {
                        ui_table_set_column_index(i32(i))
                        switch column {
                            case "id": ui_text(fmt.tprintf("%v", asset.id))
                            case "state": ui_text(fmt.tprintf("%v", asset.state))
                            case "type": ui_text(fmt.tprintf("%v", asset.type))
                            case "file_name": ui_text(fmt.tprintf("%v", asset.file_name))
                            case "info": {
                                if asset.state != .Loaded {
                                    ui_text("-")
                                    continue
                                }
                                switch in asset.info {
                                    case Asset_Info_Image: {
                                        asset_info := asset.info.(Asset_Info_Image)
                                        ui_text("width: %v, height: %v, filter: %v, wrap: %v", asset_info.texture.width, asset_info.texture.height, asset_info.texture.texture_min_filter, asset_info.texture.texture_wrap_s)
                                    }
                                    case Asset_Info_Map: {
                                        asset_info := asset.info.(Asset_Info_Map)
                                        ui_text("version: %v, levels: %v", asset_info.ldtk.jsonVersion, len(asset_info.ldtk.levels))
                                    }
                                    case Asset_Info_Sound: {
                                        // asset_info := asset.info.(Asset_Info_Image)
                                        // ui_text("width: %v, height: %v", asset_info.texture.width, asset_info.texture.height)
                                    }
                                    case Asset_Info_Shader: {
                                        asset_info := asset.info.(Asset_Info_Shader)
                                        ui_text("renderer_id: %v", asset_info.shader.renderer_id)
                                    }
                                }
                            }
                            case "actions": {
                                ui_push_id(i32(asset.id))
                                if ui_button("Inspect") {
                                    _e.assets.debug_ui_asset = asset.id
                                }
                                ui_same_line()
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

                ui_end_table()
            }
        }
    }
}
