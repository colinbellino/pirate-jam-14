package game

import "core:encoding/json"
import "core:fmt"
import "core:log"
import "core:math"
import "core:strings"

grid_to_world_position_center :: proc(grid_position: Vector2i32, rect_size: Vector2i32 = GRID_SIZE_V2) -> Vector2f32 {
    return Vector2f32 {
        f32(grid_position.x * GRID_SIZE + rect_size.x / 2),
        f32(grid_position.y * GRID_SIZE + rect_size.y / 2),
    }
}

world_to_grid_position :: proc(world_position: Vector2f32) -> Vector2i32 {
    x := f32(world_position.x / GRID_SIZE)
    y := f32(world_position.y / GRID_SIZE)
    return Vector2i32 {
        x >= 0 ? i32(x) : i32(math.ceil(x - 1)),
        y >= 0 ? i32(y) : i32(math.ceil(y - 1)),
    }
}

grid_position :: proc(x, y: i32) -> Vector2i32 {
    return { x, y } * GRID_SIZE_V2
}
