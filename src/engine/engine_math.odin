package engine

import "core:fmt"
import "core:math"
import "core:math/linalg"
import "core:testing"
import "core:log"

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

@(test)
test_engine_math :: proc(t: ^testing.T) {
    context.logger = log.create_console_logger(.Debug, { .Level, .Terminal_Color })

    {
        grid_size := Vector2i32 { 3, 3 }
        testing.expect_value(t, grid_position_is_in_bounds({  0, 0 }, grid_size), true)
        testing.expect_value(t, grid_position_is_in_bounds({  2, 0 }, grid_size), true)
        testing.expect_value(t, grid_position_is_in_bounds({  0, 2 }, grid_size), true)
        testing.expect_value(t, grid_position_is_in_bounds({  2, 2 }, grid_size), true)
        testing.expect_value(t, grid_position_is_in_bounds({  3, 0 }, grid_size), false)
        testing.expect_value(t, grid_position_is_in_bounds({  0, 3 }, grid_size), false)
        testing.expect_value(t, grid_position_is_in_bounds({ -1, 0 }, grid_size), false)
        testing.expect_value(t, grid_position_is_in_bounds({ 0, -1 }, grid_size), false)
    }
    {
        grid_size := Vector2i32 { 3, 3 }
        testing.expect_value(t, grid_index_is_in_bounds( 0, grid_size), true)
        testing.expect_value(t, grid_index_is_in_bounds( 4, grid_size), true)
        testing.expect_value(t, grid_index_is_in_bounds( 8, grid_size), true)
        testing.expect_value(t, grid_index_is_in_bounds( 9, grid_size), false)
        testing.expect_value(t, grid_index_is_in_bounds(-1, grid_size), false)
        testing.expect_value(t, grid_index_is_in_bounds(99, grid_size), false)
    }
    {
        grid_size := Vector2i32 { 3, 3 }
        testing.expect_value(t, grid_index_to_position(0, grid_size), Vector2i32 { 0, 0 })
        testing.expect_value(t, grid_index_to_position(4, grid_size), Vector2i32 { 1, 1 })
        testing.expect_value(t, grid_index_to_position(8, grid_size), Vector2i32 { 2, 2 })
    }
    {
        testing.expect_value(t, vector_equal(Vector2i32 { 0, 0 }, 0), true)
        testing.expect_value(t, vector_equal(Vector2i32 { 1, 1 }, 1), true)
        testing.expect_value(t, vector_equal(Vector2i32 { 0, 1 }, 0), false)
        testing.expect_value(t, vector_equal(Vector2i32 { 0, 1 }, 1), false)

        testing.expect_value(t, vector_equal(Vector2f32 { 0, 0 }, 0), true)
        testing.expect_value(t, vector_equal(Vector2f32 { 1.2, 1.2 }, 1.2), true)
        testing.expect_value(t, vector_equal(Vector2f32 { 0.2, 1.2 }, 0.2), false)
        testing.expect_value(t, vector_equal(Vector2f32 { 0.2, 1.2 }, 1.2), false)
    }
    {
        testing.expect_value(t, manhathan_distance({ 0,  0 }, {  0, 0 }), 0)
        testing.expect_value(t, manhathan_distance({ 0,  0 }, {  1, 0 }), 1)
        testing.expect_value(t, manhathan_distance({ 0,  0 }, { -1, 0 }), 1)
        testing.expect_value(t, manhathan_distance({ 0,  0 }, {  1, 1 }), 2)
        testing.expect_value(t, manhathan_distance({ 1, -1 }, { 0, 0 }),  2)
    }
}

grid_is_in_bounds :: proc { grid_position_is_in_bounds, grid_index_is_in_bounds }
grid_position_is_in_bounds :: proc(grid_position: Vector2i32, grid_size: Vector2i32) -> bool {
    return grid_position.x >= 0 && grid_position.x < grid_size.x && grid_position.y >= 0 && grid_position.y < grid_size.y
}
grid_index_is_in_bounds :: proc(grid_index: int, grid_size: Vector2i32) -> bool {
    return grid_index >= 0 && grid_index < int(grid_size.x * grid_size.y)
}

grid_index_to_position :: proc(grid_index: int, grid_size: Vector2i32, location := #caller_location) -> Vector2i32 {
    assert(grid_index_is_in_bounds(grid_index, grid_size), "grid_index is out of bounds")
    return Vector2i32 { i32(grid_index) % grid_size.x, i32(grid_index) / grid_size.x }
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

// TODO: test this
aabb_collides :: proc(a, b: Vector4f32) -> bool {
    return (
        a.x - a.z <= b.x - b.z &&
        a.x + a.z >= b.x + b.z &&
        a.y - a.w <= b.y - b.w &&
        a.y + a.w >= b.y + b.w
    )
}

aabb_collides_x :: proc(a, b: Vector4f32) -> bool {
    return (
        a.x - a.z <= b.x - b.z &&
        a.x + a.z >= b.x + b.z
    )
}
aabb_collides_y :: proc(a, b: Vector4f32) -> bool {
    return (
        a.y - a.w <= b.y - b.w &&
        a.y + a.w >= b.y + b.w
    )
}

texture_position_and_size :: proc(texture: ^Texture, texture_position, texture_size: Vector2i32, padding : i32 = 1, loc := #caller_location) -> (normalized_texture_position, normalized_texture_size, pixel_size: Vector2f32) {
    assert(texture != nil, "Invalid texture.", loc)
    assert(texture.width > 0, "Invalid texture: texture.width must be greater than 0.", loc)
    assert(texture.height > 0, "Invalid texture: texture.height must be greater than 0.", loc)
    assert(texture_size.x > 0, "Texture size: size.x must be greater than 0.", loc)
    assert(texture_size.y > 0, "Texture size: size.y must be greater than 0. ", loc)
    pixel_size = Vector2f32 { 1 / f32(texture.width), 1 / f32(texture.height) }
    pos := Vector2f32 { f32(texture_position.x), f32(texture_position.y) }
    size := Vector2f32 { f32(texture_size.x), f32(texture_size.y) }
    normalized_texture_position = {
        (pixel_size.x * pos.x) + (f32(padding) * pixel_size.x) + (f32(padding) * 2 * pixel_size.x * pos.x / size.x),
        (pixel_size.y * pos.y) + (f32(padding) * pixel_size.y) + (f32(padding) * 2 * pixel_size.y * pos.y / size.y),
    }
    normalized_texture_size = {
        size.x * pixel_size.x,
        size.y * pixel_size.y,
    }
    return
}

