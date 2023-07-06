package engine

import "core:mem"
import "core:math/linalg"
import "vendor:sdl2"

// FIXME: clean these up, most of this is SDL specific
Rect            :: sdl2.Rect
RectF32         :: sdl2.FRect
Renderer        :: sdl2.Renderer
TextureAccess   :: sdl2.TextureAccess
PixelFormatEnum :: sdl2.PixelFormatEnum
BlendMode       :: sdl2.BlendMode
RendererFlip    :: sdl2.RendererFlip

Renderers :: enum { SDL, OpenGL }

Debug_Line :: struct {
    start:  Vector2i32,
    end:    Vector2i32,
    color:  Color,
}

Debug_Rect :: struct {
    rect:   RectF32,
    color:  Color,
}

Renderer_State_Base :: struct {
    enabled:            bool,
    pixel_density:      f32,
    rendering_size:     Vector2i32,
    rendering_offset:   Vector2i32,
    rendering_scale:    i32,
    refresh_rate:       i32,
    draw_duration:      i32,
}

renderer_draw_window_border :: proc(window_size: Vector2i32, color: Color) {
    scale := _engine.renderer.rendering_scale
    offset := _engine.renderer.rendering_offset

    renderer_draw_quad({ 0, 0 }, { f32(window_size.x * scale + offset.x * 2), f32(offset.y) }, color)
    renderer_draw_quad({ 0, f32(window_size.y * scale + offset.y) }, { f32(window_size.x * scale + offset.x * 2), f32(offset.y) }, color)
    renderer_draw_quad({ 0, 0 }, { f32(offset.x), f32(window_size.y * scale + offset.y * 2) }, color)
    renderer_draw_quad({ f32(window_size.x * scale + offset.x), 0 }, { f32(offset.x), f32(window_size.y * scale + offset.y * 2) }, color)
}
