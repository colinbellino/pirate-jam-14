package game

import "core:container/queue"
import "core:log"
import "core:math"
import "core:runtime"
import "core:slice"
import "core:testing"
import "../engine"

Node :: struct {
    cell:     Grid_Cell,
    position: Vector2i32,
    g_cost:   i32,
    h_cost:   i32,
    parent:   ^Node,
}

CARDINAL_DIRECTIONS :: []Vector2i32 {
    { 1, 0 },
    { 0, 1 },
    { -1, 0 },
    { 0, -1 },
}
EIGHT_DIRECTIONS :: []Vector2i32 {
    { -1, -1 }, { +0, -1 }, { +1, -1 },
    { -1, +0 }, /*       */ { +1, +0 },
    { -1, +1 }, { +0, +1 }, { +1, +1 },
}
MAX_ITERATION :: 999

// TODO: I don't like that we have to pass both grid AND valid_cells. Maybe we can pass the level and valid_cells and generate the nodes from that?
find_path :: proc(grid: []Grid_Cell, grid_size: Vector2i32, start_position, end_position: Vector2i32, directions := EIGHT_DIRECTIONS, valid_cells: []Vector2i32, allocator: runtime.Allocator, loc := #caller_location) -> ([]Vector2i32, bool) #optional_ok {
    engine.profiler_zone("find_path")
    context.allocator = context.temp_allocator
    assert(grid_size.x > 0 && grid_size.y > 0, "grid_size too small", loc)
    assert(grid_size.x * grid_size.y == i32(len(grid)), "grid_size doesn't match len(grid)", loc)

    nodes := make(map[Vector2i32]Node, len(grid))
    for cell, i in grid {
        position := engine.grid_index_to_position(i, grid_size)
        nodes[position] = { cell = cell, position = position }
    }

    if engine.grid_is_in_bounds(start_position, grid_size) == false || engine.grid_is_in_bounds(end_position, grid_size) == false {
        return {}, false
    }

    start := &nodes[start_position]
    target := &nodes[end_position]
    assert(target != nil)

    open_set := make([dynamic]^Node)
    append(&open_set, start)
    closed_set := make([dynamic]^Node)

    i := 0
    for len(open_set) > 0 {
        current_index := 0
        current := open_set[current_index]
        for _, i in open_set {
            if f_cost(open_set[i]) < f_cost(current) || f_cost(open_set[i]) == f_cost(current) && open_set[i].h_cost < current.h_cost {
                current_index = i
                current = open_set[current_index]
            }
        }

        ordered_remove(&open_set, current_index)
        append(&closed_set, current)

        if current == target {
            path_array := make([dynamic]Vector2i32)
            current := target
            i := 0
            for current != start {
                append(&path_array, current.position)
                current = current.parent
                i += 1
                if i > MAX_ITERATION {
                    return {}, false
                }
            }
            append(&path_array, start_position)

            path_slice := slice.clone(path_array[:], allocator)
            slice.reverse(path_slice)
            return path_slice, true
        }

        neighbours := get_node_neighbours(nodes, current, directions)
        for neighbour in neighbours {
            neighbour_grid_index := engine.grid_position_to_index(neighbour.position, grid_size.x)
            if len(valid_cells) > 0 && slice.contains(valid_cells, neighbour.position) == false {
                continue
            }

            if _, exists := slice.linear_search(closed_set[:], neighbour); exists {
                continue
            }

            cost :: 1 // TODO: implement node travel cost
            neighbour_g_cost := current.g_cost + calculate_distance(current, neighbour) * cost
            _, exists := slice.linear_search(open_set[:], neighbour)
            if neighbour_g_cost < neighbour.g_cost || exists == false {
                neighbour.g_cost = neighbour_g_cost
                neighbour.h_cost = calculate_distance(neighbour, target)
                neighbour.parent = current

                if exists == false {
                    append(&open_set, neighbour)
                }
            }
        }

        i += 1
        if i > MAX_ITERATION {
            log.debugf("find_path gave up after %v iteration", MAX_ITERATION)
            break
        }
    }

    return {}, false
}

f_cost :: proc(node: ^Node) -> i32 { return node.g_cost + node.h_cost }

calculate_distance :: proc(a, b: ^Node) -> i32 {
    distance_x := math.abs(a.position.x - b.position.x)
    distance_y := math.abs(a.position.y - b.position.y)
    if distance_x > distance_y {
        return 14 * distance_y + 10 * (distance_x - distance_y)
    }
    return 14 * distance_x + 10 * (distance_y - distance_x)
}

get_node_neighbours :: proc(nodes: map[Vector2i32]Node, node: ^Node, directions := CARDINAL_DIRECTIONS, allocator := context.allocator) -> (neighbours: [dynamic]^Node) {
    neighbours = make([dynamic]^Node, allocator)
    for direction in directions {
        neighbour, exists := &nodes[node.position + direction]
        if exists {
            append(&neighbours, neighbour)
        }
    }
    return neighbours
}


/* Return value: 0 to stop search, 1 to stop but still add to result, 2 add to result and continue */
Flood_Search_Filter_Proc :: #type proc(cell_position: Vector2i32, grid_size: Vector2i32, grid: []Grid_Cell) -> u8
flood_search :: proc(grid_size: Vector2i32, grid: []Grid_Cell, start_position: Vector2i32, max_distance: i32, search_filter_proc: Flood_Search_Filter_Proc, directions := CARDINAL_DIRECTIONS, allocator: runtime.Allocator) -> [dynamic]Vector2i32 {
    engine.profiler_zone("flood_search")
    context.allocator = context.temp_allocator

    result := make([dynamic]Vector2i32, allocator)
    to_search := queue.Queue(Vector2i32) {}
    searched := map[Vector2i32]bool {}
    queue.push_back(&to_search, start_position)

    for queue.len(to_search) > 0 {
        cell_position := queue.pop_front(&to_search)

        if cell_position in searched {
            continue
        }
        if engine.manhathan_distance(start_position, cell_position) > max_distance {
            continue
        }

        search_filter_result := search_filter_proc(cell_position, grid_size, grid)
        if search_filter_result > 0 {
            append(&result, cell_position)

            if search_filter_result > 1 {
                for direction in directions {
                    neighbour_position := cell_position + direction
                    if engine.grid_position_is_in_bounds(neighbour_position, grid_size) == false {
                        continue
                    }
                    if neighbour_position in searched {
                        continue
                    }
                    queue.push_back(&to_search, neighbour_position)
                }
            }
        }

        searched[cell_position] = true
    }

    return result
}

/* Return value: 0 to stop search, 1 to stop but still add to result, 2 add to result and continue */
Line_Flood_Search_Filter_Proc :: #type proc(cell_position: Vector2i32) -> u8
line_search :: proc(a, b: Vector2i32, search_filter_proc: Line_Flood_Search_Filter_Proc, allocator: runtime.Allocator) -> (result: [dynamic]Vector2i32) {
    result = make([dynamic]Vector2i32, allocator)
    _a := a
    delta_x := abs(b.x - _a.x)
    sign_x : i32 = _a.x < b.x ? 1 : -1
    delta_y := -abs(b.y - _a.y)
    sign_y : i32 = _a.y < b.y ? 1 : -1
    err := delta_x + delta_y
    err2: i32

    for true {
        filter_result := search_filter_proc(_a)
        assert(filter_result >= 0)
        assert(filter_result <= 2)
        if filter_result >= 0 {
            append(&result, _a)
        }
        if filter_result < 2 {
            break
        }
        if _a.x == b.x && _a.y == b.y {
            break
        }
        err2 = 2 * err
        if err2 >= delta_y {
            err += delta_y;
            _a.x += sign_x
        }
        if err2 <= delta_x {
            err += delta_x;
            _a.y += sign_y
        }
    }

    return
}
search_filter_vision :: proc(cell_position: Vector2i32) -> u8 {
    cell, cell_found := get_cell_at_position(&_mem.game.battle_data.level, cell_position)
    if cell_found == false {
        return 0
    }
    if is_see_through(cell^) {
        return 2
    }
    return .Fog_Half in cell ? 1 : 0
}

plot_circle :: proc(center: Vector2i32, radius: i32, allocator: runtime.Allocator) -> (result: [dynamic]Vector2i32) {
    result = make([dynamic]Vector2i32, allocator)
    r := radius
    x := -radius
    y : i32 = 0
    err := 2 - 2 * radius
    for x < 0 {
        append(&result, center + { -x, +y })
        append(&result, center + { -y, -x })
        append(&result, center + { +x, -y })
        append(&result, center + { +y, +x })

        r = err
        if r <= y {
            y += 1
            err += y * 2 + 1
        }
        if r > x || err > y {
            x += 1
            err += x * 2 + 1
        }
    }
    return
}

line_of_sight_search :: proc(center: Vector2i32, distance: i32, allocator := context.allocator) -> (result: [dynamic]Vector2i32) {
    result = make([dynamic]Vector2i32, allocator)
    for i := 0; i < 2; i += 1 {
        destinations := plot_circle(center, distance - i32(i), context.temp_allocator)
        for destination in destinations {
            for cell_position in line_search(center, destination, search_filter_vision, context.temp_allocator) {
                if slice.contains(result[:], cell_position) == false {
                    append(&result, cell_position)
                }
            }
        }
    }
    return
}

calculate_octant_cells :: proc(start_position: Vector2i32, distance: i32, octant: i32) -> [dynamic]Vector2i32 {
    result := [dynamic]Vector2i32 {}
    rows: for row := 1; row <= int(distance); row += 1 {
        cols: for col := 0; col <= row; col += 1 {
            cell_position := start_position + octant_to_relative_position(i32(row), i32(col), octant)

            cell, cell_found := get_cell_at_position(&_mem.game.battle_data.level, cell_position)
            if cell_found && is_see_through(cell^) == false {
                break cols
            }

            append(&result, cell_position)
        }
    }
    return result
}
octant_to_relative_position :: proc(row, col, octant: i32) -> Vector2i32 {
    switch octant {
        case 0: return {  col, -row }
        case 1: return {  row, -col }
        case 2: return {  row,  col }
        case 3: return {  col,  row }
        case 4: return { -col,  row }
        case 5: return { -row,  col }
        case 6: return { -row, -col }
        case:   return { -col, -row }
    }
}

// This is potentially very expensive because we loop over every single cell.
grid_full_search :: proc(grid_size: Vector2i32, grid: []Grid_Cell, search_filter_proc: Flood_Search_Filter_Proc) -> [dynamic]Vector2i32 {
    result := [dynamic]Vector2i32 {}

    for y := 0; y < int(grid_size.y); y += 1 {
        for x := 0; x < int(grid_size.x); x += 1 {
            cell_position := Vector2i32 { i32(x), i32(y) }
            if search_filter_proc(cell_position, grid_size, grid) > 0 {
                append(&result, cell_position)
            }
        }
    }

    return result
}

@(test)
test_find_path :: proc(t: ^testing.T) {
    context.logger = log.create_console_logger(.Debug, { .Level, .Terminal_Color })

    LADDER := Grid_Cell { .Move, .Grounded, .Climb }
    GROUND := Grid_Cell { .Move, .Grounded, .Fall }
    grid := []Grid_Cell {
          LADDER , { .None }, { .None }, { .None }, { .None },
          LADDER , { .None }, { .None }, { .None }, { .None },
          LADDER , { .None },   GROUND , { .None }, { .None },
          GROUND ,   GROUND , { .None },   GROUND ,   GROUND ,
        { .None }, { .None }, { .None }, { .None }, { .None },
    }
    grid_size := Vector2i32 { 5, 5 }

    // {
    //     path, ok := find_path(grid, grid_size, { 0, 3 }, { 0, 3 })
    //     testing.expect(t, ok == false, "should return ko")
    //     testing.expect(t, slice.equal(path[:], []Vector2i32 { }), "should return a valid path")
    // }
    {
        path, ok := find_path(grid, grid_size, { 0, 3 }, { 0, 0 }, valid_cells = {}, allocator = context.temp_allocator)
        testing.expect(t, ok, "should return ok")
        testing.expect(t, slice.equal(path[:], []Vector2i32 { { 0, 3 }, { 0, 2 },  { 0, 1 }, { 0, 0 } }), "should return a valid path")
    }
    {
        path, ok := find_path(grid, grid_size, { 0, 3 }, { 1, 3 }, valid_cells = {}, allocator = context.temp_allocator)
        testing.expect(t, ok, "should return ok")
        testing.expect(t, slice.equal(path[:], []Vector2i32 { { 0, 3 }, { 1, 3 } }), "should return a valid path")
    }
    {
        path, ok := find_path(grid, grid_size, { 1, 3 }, { 1, 2 }, valid_cells = {}, allocator = context.temp_allocator)
        testing.expect(t, ok == false, "should return ko")
        testing.expect(t, slice.equal(path[:], []Vector2i32 { }), "should return an empty path")
    }
    {
        path, ok := find_path(grid, grid_size, { 0, 3 }, { 2, 2 }, valid_cells = {}, allocator = context.temp_allocator)
        testing.expect(t, ok, "should return ok")
        testing.expect(t, slice.equal(path[:], []Vector2i32 { { 0, 3 }, { 1, 3 }, { 2, 2 } }), "should return a valid path")
    }
    {
        path, ok := find_path(grid, grid_size, { 0, 3 }, { 4, 3 }, valid_cells = {}, allocator = context.temp_allocator)
        testing.expect(t, ok, "should return ok")
        testing.expect(t, slice.equal(path[:], []Vector2i32 { { 0, 3 }, { 1, 3 }, { 2, 2 }, { 3, 3 }, { 4, 3 } }), "should return a valid path")
    }
}
