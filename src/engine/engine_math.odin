package engine

import "core:fmt"
import "core:math/linalg"

Vector2i32      :: distinct [2]i32
Vector2f32      :: linalg.Vector2f32
Vector4f32      :: linalg.Vector4f32
Matrix4x4f32    :: linalg.Matrix4x4f32

ortho_matrix_4x4_f32 :: proc(left, right, top, bottom: f32) -> Matrix4x4f32 {
    result := linalg.MATRIX4F32_IDENTITY
    result[0][0] = 2 / (right - left)
    result[1][1] = 2 / (top - bottom)
    result[2][2] = - 1
    result[3][0] = - (right + left) / (right - left)
    result[3][1] = - (top + bottom) / (top - bottom)
    return result
}

grid_index_to_position :: proc(grid_index: i32, grid_width: i32, location := #caller_location) -> Vector2i32 {
    assert(grid_width > 0, fmt.tprintf("grid_width must be greater than 0 %v\n", location))
    return Vector2i32 { grid_index % grid_width, grid_index / grid_width }
}

grid_position_to_index :: proc(grid_position: Vector2i32, grid_width: i32) -> i32 {
    return (grid_position.y * grid_width) + grid_position.x
}
