package engine

import "core:log"
import "core:runtime"
import "core:strings"

Asset_Id :: distinct u32;

Assets :: struct {
    allocator:          runtime.Allocator,
    renderer_state:     ^Renderer_State,
    assets:             []Asset,
    assets_count:       int,
}

Asset :: struct {
    id:         Asset_Id,
    file_name:  string,
    type:       Asset_Type,
    state:      Asset_State,
    // FIXME: don't store the info in the Asset struct, move this into Asset_Slot or something
    // so we keep the info only for the assets loaded in the slots
    info:       Asset_Info,
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
    Image,
    Sound,
    Map,
}

Asset_State :: enum {
    Unloaded,
    Queued,
    Loaded,
    Locked,
}

asset_add :: proc(state: ^Assets, file_name: string, type: Asset_Type) -> Asset_Id {
    asset := Asset {};
    asset.id = Asset_Id(state.assets_count);
    asset.file_name = strings.clone(file_name, state.allocator);
    asset.type = type;
    state.assets[asset.id ] = asset;
    state.assets_count += 1;
    log.debugf("asset_add: %v", asset);
    return asset.id;
}

// TODO: Change the asset state to Queue, start loading the asset (depending on the type), update the state to Loaded
// TODO: Make this non blocking
asset_load :: proc(state: ^Assets, asset_id: Asset_Id) {
    context.allocator = state.allocator;

    log.debugf("asset_load: %v", asset_id);
    asset := &state.assets[asset_id];

    if asset.state == .Queued || asset.state == .Loaded {
        log.debug("Asset already loaded: ", asset);
        return;
    }

    asset.state = .Queued;

    switch asset.type {
        case .Image: {
            texture_index, texture, ok := _asset_load_texture(asset.file_name, state.renderer_state);
            asset.state = .Loaded;
            asset.info = Asset_Info_Image { texture };
            log.infof("Image loaded: %v", asset.file_name);
        }
        case .Sound: {

        }
        case .Map: {
            ldtk, ok := ldtk_load_file(asset.file_name);
            asset.state = .Loaded;
            asset.info = Asset_Info_Map { ldtk };
            log.infof("Map loaded: %v", asset.file_name);
        }
    }
}

asset_unload :: proc(state: ^Assets, asset_id: Asset_Id) {
    context.allocator = state.allocator;

    log.debugf("asset_unload: %v", asset_id);
    asset := &state.assets[asset_id];
    switch asset.type {
        case .Image: {
            // FIXME: our arena allocator can't really free right now.
        }
        case .Sound: {

        }
        case .Map: {
            info := asset.info.(Asset_Info_Map);
            // free(info.ldtk);
            // free(&info);
            // FIXME: our arena allocator can't really free right now.
            log.debug(asset);
        }
    }

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
_asset_load_texture :: proc(path: string, renderer_state: ^Renderer_State, allocator := context.allocator) -> (texture_index : int = -1, texture: ^Texture, ok: bool) {
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
