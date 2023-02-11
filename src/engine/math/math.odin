package engine_math

Vector2i :: struct {
    x: i32,
    y: i32,
}

grid_index_to_position :: proc(grid_index: i32, grid_width: i32) -> Vector2i {
    assert(grid_width > 0, "grid_width must be greater than 0.");
    return Vector2i { grid_index % grid_width, grid_index / grid_width };
}

grid_position_to_index :: proc(grid_position: Vector2i, grid_width: i32) -> i32 {
    return (grid_position.y * grid_width) + grid_position.x;
}
