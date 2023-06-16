package engine

import "core:fmt"
import "core:log"
import "core:math/linalg"
import "core:mem"
import "core:strings"
import "core:time"
import "vendor:sdl2"

Color           :: sdl2.Color
Vector2f32      :: linalg.Vector2f32
Texture         :: sdl2.Texture
Rect            :: sdl2.Rect
RectF32         :: sdl2.FRect
Renderer        :: sdl2.Renderer
TextureAccess   :: sdl2.TextureAccess
PixelFormatEnum :: sdl2.PixelFormatEnum
BlendMode       :: sdl2.BlendMode
RendererFlip    :: sdl2.RendererFlip
destroy_texture :: sdl2.DestroyTexture

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

// FIXME: prefix all procs with render_

renderer_init :: proc(window: ^Window, allocator: mem.Allocator, profiler_enabled: bool, vsync: bool = false) -> (ok: bool) {
    profiler_zone("renderer_init")
    _engine.renderer = new(Renderer_State, allocator)
    _engine.renderer.allocator = allocator
    if profiler_enabled {
        _engine.renderer.arena = cast(^mem.Arena)(cast(^ProfiledAllocatorData)allocator.data).backing_allocator.data
    } else {
        _engine.renderer.arena = cast(^mem.Arena)allocator.data
    }

    if vsync == false {
        sdl2.SetHint(sdl2.HINT_RENDER_VSYNC, cstring("0"))
    }

    backend_index: i32 = -1
    driver_count := sdl2.GetNumRenderDrivers()
    if driver_count <= 0 {
        log.error("No render drivers available.")
        return
    }
    for i in 0 ..< driver_count {
        info: sdl2.RendererInfo
        driver_error := sdl2.GetRenderDriverInfo(i, &info)
        if driver_error == 0 {
            // NOTE(bill): "direct3d" seems to not work correctly
            if info.name == "opengl" {
                backend_index = i
                break
            }
        }
    }

    _engine.renderer.renderer = sdl2.CreateRenderer(window, backend_index, { .ACCELERATED, .PRESENTVSYNC })
    if _engine.renderer.renderer == nil {
        log.errorf("sdl2.CreateRenderer: %v", sdl2.GetError())
        return
    }

    _engine.renderer.display_dpi = get_display_dpi(window)

    ok = true
    return
}

renderer_clear :: proc(color: Color) {
    set_draw_color(color)
    sdl2.RenderClear(_engine.renderer.renderer)
}

renderer_present :: proc() {
    sdl2.RenderPresent(_engine.renderer.renderer)
}

draw_texture :: proc {
    draw_texture_by_index,
    draw_texture_by_ptr,
}

draw_texture_by_index :: proc(texture_index: int, source: ^Rect, destination: ^RectF32, flip: RendererFlip = .NONE, color: Color = { 255, 255, 255, 255 }) {
    assert(texture_index < len(_engine.renderer.textures), fmt.tprintf("Texture out of bounds: %v", texture_index))
    texture := _engine.renderer.textures[texture_index]
    draw_texture_by_ptr(texture, source, destination, flip, color)
}

draw_texture_by_ptr :: proc(texture: ^Texture, source: ^Rect, destination: ^RectF32, flip: RendererFlip = .NONE, color: Color = { 255, 255, 255, 255 }) {
    apply_scale(destination, _engine.renderer.rendering_scale)
    apply_offset(destination, _engine.renderer.rendering_offset)
    apply_dpi(destination, _engine.renderer.display_dpi)
    sdl2.SetTextureAlphaMod(texture, color.a)
    sdl2.SetTextureColorMod(texture, color.r, color.g, color.b)
    sdl2.RenderCopyExF(_engine.renderer.renderer, texture, source, destination, 0, nil, flip)
}

draw_texture_no_offset :: proc(texture: ^Texture, source: ^Rect, destination: ^RectF32, color: Color = { 255, 255, 255, 255 }) {
    apply_scale(destination, _engine.renderer.rendering_scale)
    apply_dpi(destination, _engine.renderer.display_dpi)
    sdl2.SetTextureAlphaMod(texture, color.a)
    sdl2.SetTextureColorMod(texture, color.r, color.g, color.b)
    sdl2.RenderCopy(_engine.renderer.renderer, texture, source, &{ i32(destination.x), i32(destination.y), i32(destination.w), i32(destination.h) })
}

set_draw_color :: proc(color: Color) -> i32 {
    return sdl2.SetRenderDrawColor(_engine.renderer.renderer, color.r, color.g, color.b, color.a)
}

draw_fill_rect :: proc {
    draw_fill_rect_i32,
    draw_fill_rect_f32,
}

draw_fill_rect_i32 :: proc(destination: ^Rect, color: Color) {
    destination_f32 := make_rect_f32(destination.x, destination.y, destination.w, destination.h)
    draw_fill_rect_f32(&destination_f32, color)
}

draw_fill_rect_f32 :: proc(destination: ^RectF32, color: Color) {
    apply_scale(destination, _engine.renderer.rendering_scale)
    apply_offset(destination, _engine.renderer.rendering_offset)
    apply_dpi(destination, _engine.renderer.display_dpi)
    set_draw_color(color)
    sdl2.SetRenderDrawBlendMode(_engine.renderer.renderer, .BLEND)
    sdl2.RenderFillRectF(_engine.renderer.renderer, destination)
}

set_draw_blend_mode :: proc(mode: BlendMode) -> i32 {
    return sdl2.SetRenderDrawBlendMode(_engine.renderer.renderer, mode)
}

// Order of the apply_* calls is import: scale -> offset -> dpi

apply_scale :: proc {
    apply_scale_rect,
    apply_scale_vector2,
}
apply_scale_rect :: proc(rect: ^RectF32, scale: i32) {
    rect.x *= f32(scale)
    rect.y *= f32(scale)
    rect.w *= f32(scale)
    rect.h *= f32(scale)
}
apply_scale_vector2 :: proc(vec: ^Vector2i, scale: i32) {
    vec.x *= scale
    vec.y *= scale
}

apply_offset :: proc {
    apply_offset_rectf32,
    apply_offset_vector2i,
}
apply_offset_rectf32 :: proc(rect: ^RectF32, offset: Vector2i) {
    rect.x += f32(offset.x)
    rect.y += f32(offset.y)
}
apply_offset_vector2i :: proc(vec: ^Vector2i, offset: Vector2i) {
    vec.x += offset.x
    vec.y += offset.y
}

apply_dpi :: proc {
    apply_dpi_rectf32,
    apply_dpi_vector2i,
}
apply_dpi_rectf32 :: proc(rect: ^RectF32, dpi: f32) {
    assert(dpi != 0.0, "display_dpi is invalid (0.0).")
    rect.x *= dpi
    rect.y *= dpi
    rect.w *= dpi
    rect.h *= dpi
}
apply_dpi_vector2i :: proc(vec: ^Vector2i, dpi: f32) {
    assert(dpi != 0.0, "display_dpi is invalid (0.0).")
    vec.x = i32(f32(vec.x) * dpi)
    vec.y = i32(f32(vec.y) * dpi)
}

draw_fill_rect_no_offset :: proc(destination: ^RectF32, color: Color) {
    apply_dpi(destination, _engine.renderer.display_dpi)
    set_draw_color(color)
    // TODO: Create rectf32_to_rect
    sdl2.RenderFillRect(_engine.renderer.renderer, &{ i32(destination.x), i32(destination.y), i32(destination.w), i32(destination.h) })
}

draw_fill_rect_raw :: proc(destination: ^RectF32, color: Color) {
    set_draw_color(color)
    sdl2.RenderFillRectF(_engine.renderer.renderer, destination)
}

draw_window_border :: proc(window_size: Vector2i, color: Color) {
    scale := _engine.renderer.rendering_scale
    offset := _engine.renderer.rendering_offset

    destination_top := make_rect_f32(0, 0, window_size.x * scale + offset.x * 2, offset.y)
    draw_fill_rect_no_offset(&destination_top, color)
    destination_bottom := make_rect_f32(0, window_size.y * scale + offset.y, window_size.x * scale + offset.x * 2, offset.y)
    draw_fill_rect_no_offset(&destination_bottom, color)
    destination_left := make_rect_f32(0, 0, offset.x, window_size.y * scale + offset.y * 2)
    draw_fill_rect_no_offset(&destination_left, color)
    destination_right := make_rect_f32(window_size.x * scale + offset.x, 0, offset.x, window_size.y * scale + offset.y * 2)
    draw_fill_rect_no_offset(&destination_right, color)
}

make_rect_f32 :: proc(x, y, w, h: i32) -> RectF32 {
    return RectF32 { f32(x), f32(y), f32(w), f32(h) }
}

set_clip_rect :: proc(rect: ^Rect) {
    sdl2.RenderSetClipRect(_engine.renderer.renderer, rect)
}

take_screenshot :: proc(window: ^Window) {
    width : i32
    height : i32
    sdl2.GetRendererOutputSize(_engine.renderer.renderer, &width, &height)

    timestamp := int(time.time_to_unix(time.now()))
    path := fmt.tprintf("./screenshots/screenshot_%i.bmp", timestamp)

    surface := sdl2.CreateRGBSurface(0, width, height, 32, 0, 0, 0, 0)
    sdl2.RenderReadPixels(_engine.renderer.renderer, {}, surface.format.format, surface.pixels, surface.pitch)
    c_path := strings.clone_to_cstring(path)
    defer delete(c_path)
    sdl2.SaveBMP(surface, c_path)
    sdl2.FreeSurface(surface)

    log.debugf("Screenshot taken: %s", path)
}

render_read_pixels :: proc(rect: ^Rect, format: sdl2.PixelFormatEnum, pixels: rawptr, pitch: i32) {
    result := sdl2.RenderReadPixels(_engine.renderer.renderer, rect, u32(format), pixels, pitch)
    if result < 0 {
        log.errorf("RenderReadPixels error: %v", sdl2.GetError())
    }
}

create_texture_from_surface :: proc (surface: ^Surface) -> (texture: ^Texture, texture_index: int = -1, ok: bool) {
    texture = sdl2.CreateTextureFromSurface(_engine.renderer.renderer, surface)
    if texture == nil {
        log.errorf("Couldn't convert image to texture.")
        return
    }

    append(&_engine.renderer.textures, texture)
    texture_index = len(_engine.renderer.textures) - 1
    ok = true
    // log.debugf("create_texture_from_surface: %v -> %v", texture_index, texture)
    return
}

create_texture :: proc(pixel_format: u32, texture_access: TextureAccess, width: i32, height: i32) -> (texture: ^Texture, texture_index: int = -1, ok: bool) {
    context.allocator = _engine.renderer.allocator

    texture = sdl2.CreateTexture(_engine.renderer.renderer, pixel_format, texture_access, width, height)
    if texture == nil {
        log.errorf("Couldn't create texture.")
    }

    append(&_engine.renderer.textures, texture)
    texture_index = len(_engine.renderer.textures) - 1
    ok = true
    // log.debugf("create_texture: %v -> %v", texture_index, texture)
    return
}

set_texture_blend_mode :: proc(texture: ^Texture, blend_mode: BlendMode) -> (error: i32) {
    if _engine.renderer.disabled {
        return
    }
    error = sdl2.SetTextureBlendMode(texture, blend_mode)
    return
}

update_texture :: proc(texture: ^Texture, rect: ^Rect, pixels: rawptr, pitch: i32) -> (error: i32) {
    if _engine.renderer.disabled {
        return
    }
    error = sdl2.UpdateTexture(texture, rect, pixels, pitch)
    return
}

get_display_dpi :: proc(window: ^Window) -> f32 {
    window_size := get_window_size(window)
    output_width : i32 = 0
    output_height : i32 = 0
    sdl2.GetRendererOutputSize(_engine.renderer.renderer, &output_width, &output_height)
    return f32(output_width / window_size.x)
}

render_set_scale :: proc(scale_x: f32, scale_y: f32) -> i32 {
    return sdl2.RenderSetScale(_engine.renderer.renderer, scale_x, scale_y)
}

draw_line :: proc(pos1: ^Vector2i, pos2: ^Vector2i) -> i32 {
    apply_scale(pos1, _engine.renderer.rendering_scale)
    apply_offset(pos1, _engine.renderer.rendering_offset)
    apply_dpi(pos1, _engine.renderer.display_dpi)
    apply_scale(pos2, _engine.renderer.rendering_scale)
    apply_offset(pos2, _engine.renderer.rendering_offset)
    apply_dpi(pos2, _engine.renderer.display_dpi)
    return sdl2.RenderDrawLine(_engine.renderer.renderer, pos1.x, pos1.y, pos2.x, pos2.y)
}

query_texture :: proc(texture: ^Texture, width, height: ^i32) -> i32 {
    return sdl2.QueryTexture(texture, nil, nil, width, height)
}

set_render_target :: proc(texture: ^Texture) -> i32 {
    return sdl2.SetRenderTarget(_engine.renderer.renderer, texture)
}
