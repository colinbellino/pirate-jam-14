package engine

import "core:fmt"
import "core:log"
import "core:math/linalg"
import "core:mem"
import "core:strings"
import "core:time"
import "vendor:sdl2"

Color           :: sdl2.Color;
Vector2f32      :: linalg.Vector2f32;
Texture         :: sdl2.Texture;
Rect            :: sdl2.Rect;
RectF32         :: sdl2.FRect;
Renderer        :: sdl2.Renderer;
TextureAccess   :: sdl2.TextureAccess;
PixelFormatEnum :: sdl2.PixelFormatEnum;
BlendMode       :: sdl2.BlendMode;

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
    rendering_scale:    i32,
}

Debug_Line :: struct {
    start:  Vector2i,
    end:    Vector2i,
    color:  Color,
}

Debug_Rect :: struct {
    rect:   RectF32,
    color:  Color,
}

renderer_init :: proc(window: ^Window, allocator: mem.Allocator, profiler_enabled: bool) -> (state: ^Renderer_State, ok: bool) {
    state = new(Renderer_State, allocator);
    state.allocator = allocator;
    if profiler_enabled {
        state.arena = cast(^mem.Arena)(cast(^ProfiledAllocatorData)allocator.data).backing_allocator.data;
    } else {
        state.arena = cast(^mem.Arena)allocator.data;
    }

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
    return;
}

renderer_clear :: proc(state: ^Renderer_State, color: Color) {
    set_draw_color(state, color);
    sdl2.RenderClear(state.renderer);
}

renderer_present :: proc(state: ^Renderer_State) {
    sdl2.RenderPresent(state.renderer);
}

draw_texture :: proc {
    draw_texture_by_index,
    draw_texture_by_ptr,
}

draw_texture_by_index :: proc(state: ^Renderer_State, texture_index: int, source: ^Rect, destination: ^RectF32, color: Color = { 255, 255, 255, 255 }) {
    assert(texture_index < len(state.textures), fmt.tprintf("Texture out of bounds: %v", texture_index));
    texture := state.textures[texture_index];
    draw_texture(state, texture, source, destination, color);
}

// FIXME: update to use FRect instead of Rect2F32
draw_texture_by_ptr :: proc(state: ^Renderer_State, texture: ^Texture, source: ^Rect, destination: ^RectF32, color: Color = { 255, 255, 255, 255 }) {
    apply_scale(destination, state.rendering_scale);
    apply_offset(destination, state.rendering_offset);
    apply_dpi(destination, state.display_dpi);
    sdl2.SetTextureAlphaMod(texture, color.a);
    sdl2.SetTextureColorMod(texture, color.r, color.g, color.b);
    sdl2.RenderCopyF(state.renderer, texture, source, destination);
}

draw_texture_no_offset :: proc(state: ^Renderer_State, texture: ^Texture, source: ^Rect, destination: ^RectF32, color: Color = { 255, 255, 255, 255 }) {
    apply_scale(destination, state.rendering_scale);
    apply_dpi(destination, state.display_dpi);
    sdl2.SetTextureAlphaMod(texture, color.a);
    sdl2.SetTextureColorMod(texture, color.r, color.g, color.b);
    sdl2.RenderCopy(state.renderer, texture, source, &{ i32(destination.x), i32(destination.y), i32(destination.w), i32(destination.h) });
}

set_draw_color :: proc(state: ^Renderer_State, color: Color) -> i32 {
    return sdl2.SetRenderDrawColor(state.renderer, color.r, color.g, color.b, color.a);
}

draw_fill_rect :: proc {
    draw_fill_rect_i32,
    draw_fill_rect_f32,
};

draw_fill_rect_i32 :: proc(state: ^Renderer_State, destination: ^Rect, color: Color) {
    destination_f32 := make_rect_f32(destination.x, destination.y, destination.w, destination.h);
    draw_fill_rect_f32(state, &destination_f32, color);
}

draw_fill_rect_f32 :: proc(state: ^Renderer_State, destination: ^RectF32, color: Color) {
    set_memory_functions_temp();
    defer set_memory_functions_default();
    apply_scale(destination, state.rendering_scale);
    apply_offset(destination, state.rendering_offset);
    apply_dpi(destination, state.display_dpi);
    set_draw_color(state, color);
    sdl2.SetRenderDrawBlendMode(state.renderer, .BLEND);
    sdl2.RenderFillRect(state.renderer, &{ i32(destination.x), i32(destination.y), i32(destination.w), i32(destination.h) });
}

draw_fill_rects_i32 :: proc(state: ^Renderer_State, rects: []Rect) {
    profiler_zone("renderer.draw_fill_rects_i32");
    set_memory_functions_temp();
    defer set_memory_functions_default();
    // for rect in rects {
    //     // apply_scale(rect, state.rendering_scale);
    //     // apply_offset(rect, state.rendering_offset);
    //     // apply_dpi(rect, state.display_dpi);
    // }
    set_draw_color(state, { 255, 0, 0, 255 });
    sdl2.SetRenderDrawBlendMode(state.renderer, .BLEND);
    sdl2.RenderFillRects(state.renderer, &rects[0], i32(len(rects)));
}

// Order of the apply_* calls is import: scale -> offset -> dpi

apply_scale :: proc {
    apply_scale_rect,
    apply_scale_vector2,
};
apply_scale_rect :: proc(rect: ^RectF32, scale: i32) {
    rect.x *= f32(scale);
    rect.y *= f32(scale);
    rect.w *= f32(scale);
    rect.h *= f32(scale);
}
apply_scale_vector2 :: proc(vec: ^Vector2i, scale: i32) {
    vec.x *= scale;
    vec.y *= scale;
}

apply_offset :: proc {
    apply_offset_rectf32,
    apply_offset_vector2i,
};
apply_offset_rectf32 :: proc(rect: ^RectF32, offset: Vector2i) {
    rect.x += f32(offset.x);
    rect.y += f32(offset.y);
}
apply_offset_vector2i :: proc(vec: ^Vector2i, offset: Vector2i) {
    vec.x += offset.x;
    vec.y += offset.y;
}

apply_dpi :: proc {
    apply_dpi_rectf32,
    apply_dpi_vector2i,
};
apply_dpi_rectf32 :: proc(rect: ^RectF32, dpi: f32) {
    assert(dpi != 0.0, "display_dpi is invalid (0.0).");
    rect.x *= dpi;
    rect.y *= dpi;
    rect.w *= dpi;
    rect.h *= dpi;
}
apply_dpi_vector2i :: proc(vec: ^Vector2i, dpi: f32) {
    assert(dpi != 0.0, "display_dpi is invalid (0.0).");
    vec.x = i32(f32(vec.x) * dpi);
    vec.y = i32(f32(vec.y) * dpi);
}

draw_fill_rect_no_offset :: proc(state: ^Renderer_State, destination: ^RectF32, color: Color) {
    set_memory_functions_temp(); // TODO: use proc @annotation for this?
    defer set_memory_functions_default();
    apply_dpi(destination, state.display_dpi);
    set_draw_color(state, color);
    // TODO: Create rectf32_to_rect
    sdl2.RenderFillRect(state.renderer, &{ i32(destination.x), i32(destination.y), i32(destination.w), i32(destination.h) });
}

draw_window_border :: proc(state: ^Renderer_State, window_size: Vector2i, color: Color) {
    scale := state.rendering_scale;
    offset := state.rendering_offset;

    destination_top := make_rect_f32(0, 0, window_size.x * scale + offset.x * 2, offset.y);
    draw_fill_rect_no_offset(state, &destination_top, color);
    destination_bottom := make_rect_f32(0, window_size.y * scale + offset.y, window_size.x * scale + offset.x * 2, offset.y);
    draw_fill_rect_no_offset(state, &destination_bottom, color);
    destination_left := make_rect_f32(0, 0, offset.x, window_size.y * scale + offset.y * 2);
    draw_fill_rect_no_offset(state, &destination_left, color);
    destination_right := make_rect_f32(window_size.x * scale + offset.x, 0, offset.x, window_size.y * scale + offset.y * 2);
    draw_fill_rect_no_offset(state, &destination_right, color);
}

make_rect_f32 :: proc(x, y, w, h: i32) -> RectF32 {
    return RectF32 { f32(x), f32(y), f32(w), f32(h) };
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

create_texture_from_surface :: proc (state: ^Renderer_State, surface: ^Surface) -> (texture: ^Texture, texture_index: int = -1, ok: bool) {
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

get_display_dpi :: proc(state: ^Renderer_State, window: ^Window) -> f32 {
    window_size := get_window_size(window);
    output_width : i32 = 0;
    output_height : i32 = 0;
    sdl2.GetRendererOutputSize(state.renderer, &output_width, &output_height);
    return f32(output_width / window_size.x);
}

render_set_scale :: proc(state: ^Renderer_State, scale_x: f32, scale_y: f32) -> i32 {
    return sdl2.RenderSetScale(state.renderer, scale_x, scale_y);
}

draw_line :: proc(state: ^Renderer_State, pos1: ^Vector2i, pos2: ^Vector2i) -> i32 {
    apply_scale(pos1, state.rendering_scale);
    apply_offset(pos1, state.rendering_offset);
    apply_dpi(pos1, state.display_dpi);
    apply_scale(pos2, state.rendering_scale);
    apply_offset(pos2, state.rendering_offset);
    apply_dpi(pos2, state.display_dpi);
    return sdl2.RenderDrawLine(state.renderer, pos1.x, pos1.y, pos2.x, pos2.y);
}
