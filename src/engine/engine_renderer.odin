package engine

Renderers :: enum {
    None = 0,
    OpenGL = 1,
}

Camera_Orthographic :: struct {
    position:                   Vector3f32,
    rotation:                   f32,
    zoom:                       f32,
    projection_matrix:          Matrix4x4f32,
    view_matrix:                Matrix4x4f32,
    projection_view_matrix:     Matrix4x4f32,
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

Color_Line :: struct {
    start:  Vector2i32,
    end:    Vector2i32,
    color:  Color,
}

Color_Rect :: struct {
    rect:   Vector4f32,
    color:  Color,
}
