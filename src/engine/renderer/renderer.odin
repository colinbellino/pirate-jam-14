package engine_renderer

import "core:fmt"
import "core:log"
import "core:math"
import "core:mem"
import "core:strings"
import "core:time"
import "vendor:sdl2"

import platform "../platform"
import engine_math "../math"

Vector2i :: engine_math.Vector2i;
Color :: sdl2.Color;
Texture :: sdl2.Texture;
Rect :: sdl2.Rect;
Rectf32 :: struct {
    x: f32,
    y: f32,
    w: f32,
    h: f32,
}
Window :: sdl2.Window;
Renderer :: sdl2.Renderer;
TextureAccess :: sdl2.TextureAccess;
PixelFormatEnum :: sdl2.PixelFormatEnum;
BlendMode :: sdl2.BlendMode;

destroy_texture :: sdl2.DestroyTexture;

Renderer_State :: struct {
    arena:              ^mem.Arena,
    disabled:           bool,
    renderer:           ^Renderer,
    textures:           [dynamic]^Texture,
    display_dpi:        f32,
    rendering_size:     Vector2i,
    rendering_offset:   Vector2i,
}

@private _state: ^Renderer_State;
@private _allocator: mem.Allocator;

init :: proc(window: ^Window, allocator: mem.Allocator) -> (state: ^Renderer_State, ok: bool) {
    context.allocator = allocator;

    _allocator = allocator;
    _state = new(Renderer_State);
    _state.arena = cast(^mem.Arena)allocator.data;
    state = _state;

    // sdl2.SetHint(sdl2.HINT_RENDER_VSYNC, cstring("0"));

    backend_index: i32 = -1;
    driver_count := sdl2.GetNumRenderDrivers();
    if driver_count <= 0 {
        log.error("No render drivers available.");
        return;
    }
    for i in 0 ..< driver_count {
        info: sdl2.RendererInfo;
        driver_error := sdl2.GetRenderDriverInfo(i, &info);
        if driver_error == 0 {
            // NOTE(bill): "direct3d" seems to not work correctly
            if info.name == "opengl" {
                backend_index = i;
                break;
            }
        }
    }

    _state.renderer = sdl2.CreateRenderer(window, backend_index, { .ACCELERATED, .PRESENTVSYNC });
    if _state.renderer == nil {
        log.errorf("sdl2.CreateRenderer: %v", sdl2.GetError());
        return;
    }

    _state.display_dpi = get_display_dpi(window);

    ok = true;
    // log.info("renderer.init: OK");
    return;
}

quit :: proc() {
    sdl2.DestroyRenderer(_state.renderer);
}

clear :: proc(color: Color) {
    set_draw_color(color);
    sdl2.RenderClear(_state.renderer);
}

present :: proc() {
    sdl2.RenderPresent(_state.renderer);
}

draw_texture_by_index :: proc(texture_index: int, source: ^Rect, destination: ^Rectf32, scale: f32 = 1, color: Color = { 255, 255, 255, 255 }) {
    assert(texture_index < len(_state.textures), fmt.tprintf("Texture out of bounds: %v", texture_index));
    texture := _state.textures[texture_index];
    draw_texture(texture, source, destination, scale, color);
}

set_draw_color :: proc(color: Color) -> i32 {
    return sdl2.SetRenderDrawColor(_state.renderer, color.r, color.g, color.b, color.a);
}

draw_texture :: proc(texture: ^Texture, source: ^Rect, destination: ^Rectf32, scale: f32 = 1, color: Color = { 255, 255, 255, 255 }) {
    if _state.disabled {
        return;
    }
    dpi := _state.display_dpi;
    destination_scaled := Rect {};
    destination_scaled.x = i32(math.round((destination.x * scale + f32(_state.rendering_offset.x)) * dpi));
    destination_scaled.y = i32(math.round((destination.y * scale + f32(_state.rendering_offset.y)) * dpi));
    destination_scaled.w = i32(math.round(destination.w * dpi * scale));
    destination_scaled.h = i32(math.round(destination.h * dpi * scale));
    sdl2.SetTextureAlphaMod(texture, color.a);
    sdl2.SetTextureColorMod(texture, color.r, color.g, color.b);
    sdl2.RenderCopy(_state.renderer, texture, source, &destination_scaled);
}

draw_texture_no_offset :: proc(texture: ^Texture, source: ^Rect, destination: ^Rectf32, scale: f32 = 1, color: Color = { 255, 255, 255, 255 }) {
    if _state.disabled {
        return;
    }
    dpi := _state.display_dpi;
    destination_scaled := Rect {};
    destination_scaled.x = i32(math.round(destination.x * scale * dpi));
    destination_scaled.y = i32(math.round(destination.y * scale * dpi));
    destination_scaled.w = i32(math.round(destination.w * dpi * scale));
    destination_scaled.h = i32(math.round(destination.h * dpi * scale));
    sdl2.SetTextureAlphaMod(texture, color.a);
    sdl2.SetTextureColorMod(texture, color.r, color.g, color.b);
    sdl2.RenderCopy(_state.renderer, texture, source, &destination_scaled);
}

draw_fill_rect :: proc(destination: ^Rect, color: Color, scale: f32 = 1) {
    assert(_state.display_dpi != 0.0, "display_dpi is invalid (0.0).");
    if _state.disabled {
        return;
    }
    // platform.set_memory_functions_temp();
    // defer platform.set_memory_functions_default();
    dpi := _state.display_dpi;
    destination_scaled := Rect {};
    destination_scaled.x = i32((f32(destination.x) * scale + f32(_state.rendering_offset.x)) * dpi);
    destination_scaled.y = i32((f32(destination.y) * scale + f32(_state.rendering_offset.y)) * dpi);
    destination_scaled.w = i32(f32(destination.w) * dpi * scale);
    destination_scaled.h = i32(f32(destination.h) * dpi * scale);
    set_draw_color(color);
    sdl2.RenderFillRect(_state.renderer, &destination_scaled);
}

draw_fill_rect_no_offset :: proc(destination: ^Rect, color: Color) {
    assert(_state.display_dpi != 0.0, "display_dpi is invalid (0.0).");
    if _state.disabled {
        return;
    }
    // platform.set_memory_functions_temp(); // TODO: use proc @annotation for this?
    // defer platform.set_memory_functions_default();
    destination_scaled := Rect {};
    destination_scaled.x = i32(f32(destination.x) * _state.display_dpi);
    destination_scaled.y = i32(f32(destination.y) * _state.display_dpi);
    destination_scaled.w = i32(f32(destination.w) * _state.display_dpi);
    destination_scaled.h = i32(f32(destination.h) * _state.display_dpi);
    set_draw_color(color);
    sdl2.RenderFillRect(_state.renderer, &destination_scaled);
}

draw_window_border :: proc(window_size: Vector2i, color: Color) {
    if window_size == _state.rendering_size {
        return;
    }

    // Top
    draw_fill_rect_no_offset(&{ 0, 0, window_size.x, _state.rendering_offset.y }, color);
    // Bottom
    draw_fill_rect_no_offset(&{ 0, window_size.y - _state.rendering_offset.y, window_size.x, _state.rendering_offset.y }, color);
    // Left
    draw_fill_rect_no_offset(&{ 0, 0, _state.rendering_offset.x, window_size.y }, color);
    // Right
    draw_fill_rect_no_offset(&{ window_size.x - _state.rendering_offset.x, 0, _state.rendering_offset.x, window_size.y }, color);
}

set_clip_rect :: proc(rect: ^Rect) {
    sdl2.RenderSetClipRect(_state.renderer, rect);
}

take_screenshot :: proc(window: ^Window) {
    width : i32;
    height : i32;
    sdl2.GetRendererOutputSize(_state.renderer, &width, &height);

    timestamp := int(time.time_to_unix(time.now()));
    path := fmt.tprintf("./screenshots/screenshot_%i.bmp", timestamp);

    surface := sdl2.CreateRGBSurface(0, width, height, 32, 0, 0, 0, 0);
    sdl2.RenderReadPixels(_state.renderer, {}, surface.format.format, surface.pixels, surface.pitch);
    c_path := strings.clone_to_cstring(path)
    defer delete(c_path);
    sdl2.SaveBMP(surface, c_path);
    sdl2.FreeSurface(surface);

    log.debugf("Screenshot taken: %s", path);
}

create_texture_from_surface :: proc (surface: ^platform.Surface) -> (texture: ^Texture, texture_index: int = -1, ok: bool) {
    texture = sdl2.CreateTextureFromSurface(_state.renderer, surface);
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

    texture = sdl2.CreateTexture(_state.renderer, pixel_format, texture_access, width, height);
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
    if _state.disabled {
        return;
    }
    error = sdl2.SetTextureBlendMode(texture, blend_mode);
    return;
}

update_texture :: proc(texture: ^Texture, rect: ^Rect, pixels: rawptr, pitch: i32) -> (error: i32) {
    if _state.disabled {
        return;
    }
    error = sdl2.UpdateTexture(texture, rect, pixels, pitch);
    return;
}

get_display_dpi :: proc(window: ^platform.Window) -> f32 {
    window_size := platform.get_window_size(window);
    output_width : i32 = 0;
    output_height : i32 = 0;
    sdl2.GetRendererOutputSize(_state.renderer, &output_width, &output_height);
    return f32(output_width / window_size.x);
}

draw_line :: proc(pos1: Vector2i, pos2: Vector2i) -> i32 {
    return sdl2.RenderDrawLine(_state.renderer, pos1.x, pos1.y, pos2.x, pos2.y);
}
