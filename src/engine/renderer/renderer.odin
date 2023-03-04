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
    allocator:          mem.Allocator,
    disabled:           bool,
    renderer:           ^Renderer,
    textures:           [dynamic]^Texture,
    display_dpi:        f32,
    rendering_size:     Vector2i,
    rendering_offset:   Vector2i,
}

init :: proc(window: ^Window, allocator: mem.Allocator) -> (state: ^Renderer_State, ok: bool) {
    state = new(Renderer_State, allocator);
    state.allocator = allocator;
    state.arena = cast(^mem.Arena)allocator.data;

    sdl2.SetHint(sdl2.HINT_RENDER_VSYNC, cstring("0"));

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

    state.renderer = sdl2.CreateRenderer(window, backend_index, { .ACCELERATED, .PRESENTVSYNC });
    if state.renderer == nil {
        log.errorf("sdl2.CreateRenderer: %v", sdl2.GetError());
        return;
    }

    state.display_dpi = get_display_dpi(state, window);

    ok = true;
    // log.info("renderer.init: OK");
    return;
}

quit :: proc(state: ^Renderer_State) {
    sdl2.DestroyRenderer(state.renderer);
}

clear :: proc(state: ^Renderer_State, color: Color) {
    set_draw_color(state, color);
    sdl2.RenderClear(state.renderer);
}

present :: proc(state: ^Renderer_State) {
    sdl2.RenderPresent(state.renderer);
}

draw_texture_by_index :: proc(state: ^Renderer_State, texture_index: int, source: ^Rect, destination: ^Rectf32, scale: f32 = 1, color: Color = { 255, 255, 255, 255 }) {
    assert(texture_index < len(state.textures), fmt.tprintf("Texture out of bounds: %v", texture_index));
    texture := state.textures[texture_index];
    draw_texture(state, texture, source, destination, scale, color);
}

set_draw_color :: proc(state: ^Renderer_State, color: Color) -> i32 {
    return sdl2.SetRenderDrawColor(state.renderer, color.r, color.g, color.b, color.a);
}

draw_texture :: proc(state: ^Renderer_State, texture: ^Texture, source: ^Rect, destination: ^Rectf32, scale: f32 = 1, color: Color = { 255, 255, 255, 255 }) {
    if state.disabled {
        return;
    }
    dpi := state.display_dpi;
    destination_scaled := Rect {};
    destination_scaled.x = i32(math.round((destination.x * scale + f32(state.rendering_offset.x)) * dpi));
    destination_scaled.y = i32(math.round((destination.y * scale + f32(state.rendering_offset.y)) * dpi));
    destination_scaled.w = i32(math.round(destination.w * dpi * scale));
    destination_scaled.h = i32(math.round(destination.h * dpi * scale));
    sdl2.SetTextureAlphaMod(texture, color.a);
    sdl2.SetTextureColorMod(texture, color.r, color.g, color.b);
    sdl2.RenderCopy(state.renderer, texture, source, &destination_scaled);
}

draw_texture_no_offset :: proc(state: ^Renderer_State, texture: ^Texture, source: ^Rect, destination: ^Rectf32, scale: f32 = 1, color: Color = { 255, 255, 255, 255 }) {
    if state.disabled {
        return;
    }
    dpi := state.display_dpi;
    destination_scaled := Rect {};
    destination_scaled.x = i32(math.round(destination.x * scale * dpi));
    destination_scaled.y = i32(math.round(destination.y * scale * dpi));
    destination_scaled.w = i32(math.round(destination.w * dpi * scale));
    destination_scaled.h = i32(math.round(destination.h * dpi * scale));
    sdl2.SetTextureAlphaMod(texture, color.a);
    sdl2.SetTextureColorMod(texture, color.r, color.g, color.b);
    sdl2.RenderCopy(state.renderer, texture, source, &destination_scaled);
}

draw_fill_rect :: proc(state: ^Renderer_State, destination: ^Rect, color: Color, scale: f32 = 1) {
    assert(state.display_dpi != 0.0, "display_dpi is invalid (0.0).");
    if state.disabled {
        return;
    }
    platform.set_memory_functions_temp();
    defer platform.set_memory_functions_default();
    dpi := state.display_dpi;
    destination_scaled := Rect {};
    destination_scaled.x = i32((f32(destination.x) * scale + f32(state.rendering_offset.x)) * dpi);
    destination_scaled.y = i32((f32(destination.y) * scale + f32(state.rendering_offset.y)) * dpi);
    destination_scaled.w = i32(f32(destination.w) * dpi * scale);
    destination_scaled.h = i32(f32(destination.h) * dpi * scale);
    set_draw_color(state, color);
    sdl2.RenderFillRect(state.renderer, &destination_scaled);
}

draw_fill_rect_no_offset :: proc(state: ^Renderer_State, destination: ^Rect, color: Color) {
    assert(state.display_dpi != 0.0, "display_dpi is invalid (0.0).");
    if state.disabled {
        return;
    }
    platform.set_memory_functions_temp(); // TODO: use proc @annotation for this?
    defer platform.set_memory_functions_default();
    destination_scaled := Rect {};
    destination_scaled.x = i32(f32(destination.x) * state.display_dpi);
    destination_scaled.y = i32(f32(destination.y) * state.display_dpi);
    destination_scaled.w = i32(f32(destination.w) * state.display_dpi);
    destination_scaled.h = i32(f32(destination.h) * state.display_dpi);
    set_draw_color(state, color);
    sdl2.RenderFillRect(state.renderer, &destination_scaled);
}

draw_window_border :: proc(state: ^Renderer_State, window_size: Vector2i, color: Color) {
    if window_size == state.rendering_size {
        return;
    }

    // Top
    draw_fill_rect_no_offset(state, &{ 0, 0, window_size.x, state.rendering_offset.y }, color);
    // Bottom
    draw_fill_rect_no_offset(state, &{ 0, window_size.y - state.rendering_offset.y, window_size.x, state.rendering_offset.y }, color);
    // Left
    draw_fill_rect_no_offset(state, &{ 0, 0, state.rendering_offset.x, window_size.y }, color);
    // Right
    draw_fill_rect_no_offset(state, &{ window_size.x - state.rendering_offset.x, 0, state.rendering_offset.x, window_size.y }, color);
}

set_clip_rect :: proc(state: ^Renderer_State, rect: ^Rect) {
    sdl2.RenderSetClipRect(state.renderer, rect);
}

take_screenshot :: proc(state: ^Renderer_State, window: ^Window) {
    width : i32;
    height : i32;
    sdl2.GetRendererOutputSize(state.renderer, &width, &height);

    timestamp := int(time.time_to_unix(time.now()));
    path := fmt.tprintf("./screenshots/screenshot_%i.bmp", timestamp);

    surface := sdl2.CreateRGBSurface(0, width, height, 32, 0, 0, 0, 0);
    sdl2.RenderReadPixels(state.renderer, {}, surface.format.format, surface.pixels, surface.pitch);
    c_path := strings.clone_to_cstring(path)
    defer delete(c_path);
    sdl2.SaveBMP(surface, c_path);
    sdl2.FreeSurface(surface);

    log.debugf("Screenshot taken: %s", path);
}

create_texture_from_surface :: proc (state: ^Renderer_State, surface: ^platform.Surface) -> (texture: ^Texture, texture_index: int = -1, ok: bool) {
    texture = sdl2.CreateTextureFromSurface(state.renderer, surface);
    if texture == nil {
        log.errorf("Couldn't convert image to texture.");
        return;
    }

    append(&state.textures, texture);
    texture_index = len(state.textures) - 1;
    ok = true;
    // log.debugf("create_texture_from_surface: %v -> %v", texture_index, texture);
    return;
}

create_texture :: proc(state: ^Renderer_State, pixel_format: u32, texture_access: TextureAccess, width: i32, height: i32) -> (texture: ^Texture, texture_index: int = -1, ok: bool) {
    context.allocator = state.allocator;

    texture = sdl2.CreateTexture(state.renderer, pixel_format, texture_access, width, height);
    if texture == nil {
        log.errorf("Couldn't create texture.");
    }

    append(&state.textures, texture);
    texture_index = len(state.textures) - 1;
    ok = true;
    // log.debugf("create_texture: %v -> %v", texture_index, texture);
    return;
}

set_texture_blend_mode :: proc(state: ^Renderer_State, texture: ^Texture, blend_mode: BlendMode) -> (error: i32) {
    if state.disabled {
        return;
    }
    error = sdl2.SetTextureBlendMode(texture, blend_mode);
    return;
}

update_texture :: proc(state: ^Renderer_State, texture: ^Texture, rect: ^Rect, pixels: rawptr, pitch: i32) -> (error: i32) {
    if state.disabled {
        return;
    }
    error = sdl2.UpdateTexture(texture, rect, pixels, pitch);
    return;
}

get_display_dpi :: proc(state: ^Renderer_State, window: ^platform.Window) -> f32 {
    window_size := platform.get_window_size(window);
    output_width : i32 = 0;
    output_height : i32 = 0;
    sdl2.GetRendererOutputSize(state.renderer, &output_width, &output_height);
    return f32(output_width / window_size.x);
}

draw_line :: proc(state: ^Renderer_State, pos1: Vector2i, pos2: Vector2i) -> i32 {
    return sdl2.RenderDrawLine(state.renderer, pos1.x, pos1.y, pos2.x, pos2.y);
}
