package engine

Renderers :: enum {
    None = 0,
    OpenGL = 1,
    Sokol = 2,
}

Camera_Orthographic :: struct {
    position:                   Vector3f32,
    rotation:                   f32,
    zoom:                       f32,
    projection_matrix:          Matrix4x4f32,
    view_matrix:                Matrix4x4f32,
    view_projection_matrix:     Matrix4x4f32,
}

Color :: struct {
    r, g, b, a: f32,
}

Quad :: struct {
    position:               Vector2f32,
    color:                  Color,
    texture_coordinates:    Vector2f32,
    texture_index:          i32,
    palette_index:          i32, /* -1: no palette, 0+: palette index */
}

Line :: struct {
    points:             []Vector2f32,
    points_count:       i32,
    points_color:       Color,
    points_radius:      f32,
    lines_color:        Color,
    lines_thickness:    f32,
}

// TODO: remove this after line renderer is done
Color_Line :: struct {
    start:  Vector2i32,
    end:    Vector2i32,
    color:  Color,
}

Color_Rect :: struct {
    rect:   Vector4f32,
    color:  Color,
}

Color_Palette :: distinct [PALETTE_SIZE]Color

Renderer_Stats :: struct {
    quad_count: u32,
    draw_count: u32,
}

PALETTE_SIZE    :: 32
PALETTE_MAX     :: 4

renderer_make_palette :: proc(colors: [PALETTE_SIZE][4]u8) -> Color_Palette {
    result := Color_Palette {}
    for color, i in colors {
        result[i] = { f32(color.r) / 255, f32(color.g) / 255, f32(color.b) / 255, f32(color.a) / 255 }
    }
    return result
}
