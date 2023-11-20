package engine

import "core:fmt"
import "core:math"
import "core:math/linalg"

Vector2i32                  :: distinct [2]i32
Vector4i32                  :: distinct [4]i32
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

grid_position_is_in_bounds :: proc(grid_position: Vector2i32, grid_size: Vector2i32) -> bool {
    return grid_position.x >= 0 && grid_position.x < grid_size.x && grid_position.y >= 0 && grid_position.y < grid_size.y
}
grid_index_is_in_bounds :: proc(grid_index: int, grid_size: Vector2i32) -> bool {
    return grid_index > 0 && grid_index < int(grid_size.x * grid_size.y)
}

grid_index_to_position :: proc(grid_index: int, grid_width: i32, location := #caller_location) -> Vector2i32 {
    profiler_zone("grid_index_to_position")
    assert(grid_width > 0, fmt.tprintf("grid_width must be greater than 0 %v\n", location))
    return Vector2i32 { i32(grid_index) % grid_width, i32(grid_index) / grid_width }
}

grid_position_to_index :: proc(grid_position: Vector2i32, grid_width: i32) -> int {
    return int((grid_position.y * grid_width) + grid_position.x)
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

manhathan_distance :: proc(a, b: Vector2i32) -> i32 {
    return math.abs(a.x - b.x) + math.abs(a.y - b.y)
}
