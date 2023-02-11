package engine_math

Vector2i :: struct {
    x: int,
    y: int,
}

grid_index_to_position :: proc(grid_index: int, grid_width: int) -> (int, int) {
    assert(grid_width > 0, "grid_width must be greater than 0.");
    return grid_index % grid_width, grid_index / grid_width;
}
