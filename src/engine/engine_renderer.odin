package engine

import "vendor:sdl2"

// FIXME: clean these up, most of this is SDL specific
Rect            :: sdl2.Rect
RectF32         :: sdl2.FRect
Renderer        :: sdl2.Renderer
TextureAccess   :: sdl2.TextureAccess
PixelFormatEnum :: sdl2.PixelFormatEnum
BlendMode       :: sdl2.BlendMode

Renderer_Flips :: enum u8 {
    None       = 0b00000000,
    Horizontal = 0b00000001,
    Vertical   = 0b00000010,
}

Renderer_Flip :: bit_set[Renderer_Flips]

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
    refresh_rate:       i32,
    draw_duration:      i32,
}
