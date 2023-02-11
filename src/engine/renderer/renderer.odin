package engine_renderer

import "core:fmt"
import "core:log"
import "core:mem"
import "core:os"
import "core:runtime"
import "core:slice"
import "core:strings"
import "core:time"
import sdl "vendor:sdl2"

import platform "../platform"

Color :: sdl.Color;
Texture :: sdl.Texture;
Rect :: sdl.Rect;
Window :: sdl.Window;
Renderer :: sdl.Renderer;
TextureAccess :: sdl.TextureAccess;
PixelFormatEnum :: sdl.PixelFormatEnum;
BlendMode :: sdl.BlendMode;

destroy_texture :: sdl.DestroyTexture;

State :: struct {
    renderer:       ^Renderer,
    textures:       [dynamic]^Texture,
}

@private _state: ^State;
@private _allocator: mem.Allocator;

init :: proc(window: ^Window, allocator: mem.Allocator) -> (state: ^State, ok: bool) {
    context.allocator = allocator;
    _allocator = allocator;
    _state = new(State);
    state = _state;

    backend_idx: i32 = -1;
    n := sdl.GetNumRenderDrivers();

    if n <= 0 {
        log.error("No render drivers available");
        return;
    }

    for i in 0..<n {
        info: sdl.RendererInfo;
        if err := sdl.GetRenderDriverInfo(i, &info); err == 0 {
            // NOTE(bill): "direct3d" seems to not work correctly
            if info.name == "opengl" {
                backend_idx = i;
                break;
            }
        }
    }

    _state.renderer = sdl.CreateRenderer(window, backend_idx, {.ACCELERATED, .PRESENTVSYNC});
    if _state.renderer == nil {
        log.errorf("sdl.CreateRenderer: %v", sdl.GetError());
        return;
    }

    ok = true;
    log.info("renderer.init: OK");
    return;
}

quit :: proc() {
    sdl.DestroyRenderer(_state.renderer);
}

clear :: proc(color: Color) {
    viewport_rect := &Rect{};
    sdl.GetRendererOutputSize(_state.renderer, &viewport_rect.w, &viewport_rect.h);
    sdl.RenderSetViewport(_state.renderer, viewport_rect);
    sdl.RenderSetClipRect(_state.renderer, viewport_rect);
    sdl.SetRenderDrawColor(_state.renderer, color.r, color.g, color.b, color.a);
    sdl.RenderClear(_state.renderer);
}

present :: proc() {
    sdl.RenderPresent(_state.renderer);
}

draw_texture_by_index :: proc(texture_index: int, source_rect: ^Rect, destination_rect: ^Rect, color: Color = Color { 255, 255, 255, 255 }) {
    assert(texture_index < len(_state.textures), fmt.tprintf("Texture out of bounds: %v", texture_index));
    texture := _state.textures[texture_index];
    draw_texture(texture, source_rect, destination_rect, color);
}

draw_texture :: proc(texture: ^Texture, source_rect: ^Rect, destination_rect: ^Rect, color: Color) {
    sdl.SetTextureAlphaMod(texture, color.a);
    sdl.SetTextureColorMod(texture, color.r, color.g, color.b);
    sdl.RenderCopy(_state.renderer, texture, source_rect, destination_rect);
}

take_screenshot :: proc(window: ^Window) {
    width : i32;
    height : i32;
    sdl.GetRendererOutputSize(_state.renderer, &width, &height);

    timestamp := int(time.time_to_unix(time.now()));
    path := fmt.tprintf("./screenshots/screenshot_%i.bmp", timestamp);

    surface := sdl.CreateRGBSurface(0, width, height, 32, 0, 0, 0, 0);
    sdl.RenderReadPixels(_state.renderer, {}, surface.format.format, surface.pixels, surface.pitch);
    sdl.SaveBMP(surface, strings.clone_to_cstring(path));
    sdl.FreeSurface(surface);

    log.debugf("Screenshot taken: %s", path);
}

create_texture_from_surface :: proc (surface: ^platform.Surface) -> (texture: ^Texture, texture_index: int = -1, ok: bool) {
    texture = sdl.CreateTextureFromSurface(_state.renderer, surface);
    if texture == nil {
        log.errorf("Couldn't convert image to texture.");
        return;
    }

    append(&_state.textures, texture);
    texture_index = len(_state.textures) - 1;
    ok = true;
    // log.debugf("create_texture_from_surface: %v -> %v", texture_index, texture);
    return;
}

create_texture :: proc(pixel_format: u32, texture_access: TextureAccess, width: i32, height: i32) -> (texture: ^Texture, texture_index: int = -1, ok: bool) {
    context.allocator = _allocator;

    texture = sdl.CreateTexture(_state.renderer, pixel_format, texture_access, width, height);
    if texture == nil {
        log.errorf("Couldn't create texture.");
    }

    append(&_state.textures, texture);
    texture_index = len(_state.textures) - 1;
    ok = true;
    // log.debugf("create_texture: %v -> %v", texture_index, texture);
    return;
}

set_texture_blend_mode :: proc(texture: ^Texture, blend_mode: BlendMode) -> (error: i32) {
    error = sdl.SetTextureBlendMode(texture, blend_mode);
    return;
}

update_texture :: proc(texture: ^Texture, rect: ^Rect, pixels: rawptr, pitch: i32) -> (error: i32) {
    error = sdl.UpdateTexture(texture, rect, pixels, pitch);
    return;
}

draw_fill_rect :: proc(rect: ^Rect, color: Color) {
    // platform.temp_allocs();
    sdl.SetRenderDrawColor(_state.renderer, color.r, color.g, color.b, color.a);
    sdl.RenderFillRect(_state.renderer, rect);
    // platform.persistent_allocs();
}

set_clip_rect :: proc(rect: ^Rect) {
    sdl.RenderSetClipRect(_state.renderer, rect);
}

allocator_proc :: proc(
    allocator_data: rawptr, mode: mem.Allocator_Mode,
    size, alignment: int,
    old_memory: rawptr, old_size: int, location := #caller_location,
) -> (result: []byte, error: mem.Allocator_Error) {
    if slice.contains(os.args, "show-alloc") {
        fmt.printf("[RENDERER] %v %v byte at %v\n", mode, size, location);
    }
    result, error = runtime.default_allocator_proc(allocator_data, mode, size, alignment, old_memory, old_size, location);
    if error > .None {
        fmt.eprintf("[RENDERER] alloc error %v\n", error);
        os.exit(0);
    }
    return;
}
