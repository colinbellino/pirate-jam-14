package game

import "core:math"

grid_to_world_position_center :: proc(grid_position: Vector2i32, rect_size: Vector2i32 = GRID_SIZE_V2) -> Vector2f32 {
    return Vector2f32 {
        f32(grid_position.x * GRID_SIZE + rect_size.x / 2),
        f32(grid_position.y * GRID_SIZE + rect_size.y / 2),
    }
}

pixel_to_grid_position :: proc(world_position: Vector2f32, loc := #caller_location) -> Vector2i32 {
    return {
        i32(math.floor(world_position.x / GRID_SIZE_F32)),
        i32(math.floor(world_position.y / GRID_SIZE_F32)),
    }
}

world_to_grid_position :: proc(world_position: Vector2f32, loc := #caller_location) -> Vector2i32 {
    return {
        i32(math.floor(world_position.x / GRID_SIZE_F32)),
        i32(math.floor(world_position.y / GRID_SIZE_F32)),
    }
}

grid_position :: proc(x, y: i32) -> Vector2i32 {
    return { x, y } * GRID_SIZE_V2
}
