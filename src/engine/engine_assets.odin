package engine

import "core:log"
import "core:runtime"

Asset_Id :: distinct u32;

Assets :: struct {
    allocator:          runtime.Allocator,
    assets:             [200]Asset,
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

Asset_Info_Image :: struct { }
Asset_Info_Sound :: struct { }
Asset_Info_Map :: struct {
    ldtk:   LDTK_Root,
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
    asset.file_name = file_name;
    asset.type = type;
    state.assets[asset.id ] = asset;
    state.assets_count += 1;
    log.debugf("asset_add: %v", asset);
    return asset.id;
}

// TODO: Change the asset state to Queue, start loading the asset (depending on the type), update the state to Loaded
// TODO: Make this non blocking
asset_load :: proc(state: ^Assets, asset_id: Asset_Id) {
    log.debugf("asset_load: %v", asset_id);
    asset := &state.assets[asset_id];

    if asset.state == .Queued || asset.state == .Loaded {
        log.debug("already loaded: ", asset);
        return;
    }

    asset.state = .Queued;

    switch asset.type {
        case .Image: {
            // _asset_load_texture(platform_state, renderer_state, "media/art/placeholder_0.png");
        }
        case .Sound: {

        }
        case .Map: {
            ldtk, ok := ldtk_load_file(asset.file_name, state.allocator);
            asset.info = Asset_Info_Map { ldtk };
            asset.state = .Loaded;
        }
    }
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
_asset_load_texture :: proc(platform_state: ^Platform_State, renderer_state: ^Renderer_State, path: string) -> (texture_index : int = -1, texture: ^Texture, ok: bool) {
    surface : ^Surface;
    surface, ok = load_surface_from_image_file(platform_state, path);
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

    log.infof("Texture loaded: %v", path);
    return;
}
