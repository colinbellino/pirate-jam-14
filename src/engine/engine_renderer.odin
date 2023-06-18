package engine

import "core:mem"
import "core:math/linalg"
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

Renderers :: enum { SDL, OpenGL }

Debug_Line :: struct {
    start:  Vector2i,
    end:    Vector2i,
    color:  Color,
}

Debug_Rect :: struct {
    rect:   RectF32,
    color:  Color,
}

Renderer_State :: struct {
    arena:              ^mem.Arena,
    allocator:          mem.Allocator,
    enabled:            bool,
    renderer:           ^Renderer,
    textures:           [dynamic]^Texture,
    display_dpi:        f32,
    rendering_size:     Vector2i,
    rendering_offset:   Vector2i,
    rendering_scale:    i32,
}

renderer_draw_texture :: proc {
    renderer_draw_texture_by_index,
    renderer_draw_texture_by_ptr,
}

renderer_draw_fill_rect :: proc {
    renderer_draw_fill_rect_i32,
    renderer_draw_fill_rect_f32,
}

renderer_draw_window_border :: proc(window_size: Vector2i, color: Color) {
    scale := _engine.renderer.rendering_scale
    offset := _engine.renderer.rendering_offset

    destination_top := renderer_make_rect_f32(0, 0, window_size.x * scale + offset.x * 2, offset.y)
    renderer_draw_fill_rect_no_offset(&destination_top, color)
    destination_bottom := renderer_make_rect_f32(0, window_size.y * scale + offset.y, window_size.x * scale + offset.x * 2, offset.y)
    renderer_draw_fill_rect_no_offset(&destination_bottom, color)
    destination_left := renderer_make_rect_f32(0, 0, offset.x, window_size.y * scale + offset.y * 2)
    renderer_draw_fill_rect_no_offset(&destination_left, color)
    destination_right := renderer_make_rect_f32(window_size.x * scale + offset.x, 0, offset.x, window_size.y * scale + offset.y * 2)
    renderer_draw_fill_rect_no_offset(&destination_right, color)
}
