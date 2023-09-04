package engine

import "core:fmt"
import "core:math/linalg"

Vector2i32                  :: distinct [2]i32
Vector2f32                  :: linalg.Vector2f32
Vector3f32                  :: linalg.Vector3f32
Vector4f32                  :: linalg.Vector4f32
Matrix4x4f32                :: linalg.Matrix4x4f32
matrix_ortho3d_f32          :: linalg.matrix_ortho3d_f32
matrix4_perspective_f32     :: linalg.matrix4_perspective_f32
matrix4_translate_f32       :: linalg.matrix4_translate_f32
matrix4_scale_f32           :: linalg.matrix4_scale_f32
matrix4_rotate_f32          :: linalg.matrix4_rotate_f32
matrix4_inverse_f32         :: linalg.matrix4_inverse_f32

grid_index_to_position :: proc(grid_index: i32, grid_width: i32, location := #caller_location) -> Vector2i32 {
    assert(grid_width > 0, fmt.tprintf("grid_width must be greater than 0 %v\n", location))
    return Vector2i32 { grid_index % grid_width, grid_index / grid_width }
}

grid_position_to_index :: proc(grid_position: Vector2i32, grid_width: i32) -> i32 {
    return (grid_position.y * grid_width) + grid_position.x
}

vector_i32_to_f32 :: proc(vector: Vector2i32) -> Vector2f32 {
    return Vector2f32(linalg.array_cast(vector, f32))
}

vector_equal :: proc { vector_equal_i32, vector_equal_f32 }
vector_equal_i32 :: proc(vector: Vector2i32, value: i32) -> bool {
    return vector.x == value && vector.y == value
}
vector_equal_f32 :: proc(vector: Vector2f32, value: f32) -> bool {
    return vector.x == value && vector.y == value
}

vector_not_equal :: proc { vector_not_equal_i32, vector_not_equal_f32 }
vector_not_equal_i32 :: proc(vector: Vector2i32, value: i32) -> bool {
    return vector_equal(vector, value) == false
}
vector_not_equal_f32 :: proc(vector: Vector2f32, value: f32) -> bool {
    return vector_equal(vector, value) == false
}
