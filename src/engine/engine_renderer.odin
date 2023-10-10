package engine

Renderers :: enum {
    None = 0,
    OpenGL = 1,
}

Debug_Line :: struct {
    start:  Vector2i32,
    end:    Vector2i32,
    color:  Color,
}

Debug_Rect :: struct {
    rect:   Vector4f32,
    color:  Color,
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
