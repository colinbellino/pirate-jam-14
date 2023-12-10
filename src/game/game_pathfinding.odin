package game

import "core:container/queue"
import "core:fmt"
import "core:log"
import "core:math"
import "core:runtime"
import "core:slice"
import "core:testing"
import "../engine"
import "../tools"

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

find_path :: proc(grid: []Grid_Cell, grid_size: Vector2i32, start_position, end_position: Vector2i32, directions := EIGHT_DIRECTIONS, allocator: runtime.Allocator, loc := #caller_location) -> ([]Vector2i32, bool) #optional_ok {
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
            if is_valid_move_destination(neighbour.cell) == false {
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

Search_Filter_Proc :: #type proc(cell_position: Vector2i32, grid_size: Vector2i32, grid: []Grid_Cell) -> bool

flood_fill_search :: proc(grid_size: Vector2i32, grid: []Grid_Cell, start_position: Vector2i32, max_distance: i32, search_filter_proc: Search_Filter_Proc, directions := CARDINAL_DIRECTIONS, allocator: runtime.Allocator) -> [dynamic]Vector2i32 {
    engine.profiler_zone("flood_fill_search")
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

        if search_filter_proc(cell_position, grid_size, grid) {
            append(&result, cell_position)

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

        searched[cell_position] = true
    }

    return result
}

// This is potentially very expensive because we loop over every single cell.
grid_full_search :: proc(grid_size: Vector2i32, grid: []Grid_Cell, search_filter_proc: Search_Filter_Proc) -> [dynamic]Vector2i32 {
    result := [dynamic]Vector2i32 {}

    for y := 0; y < int(grid_size.y); y += 1 {
        for x := 0; x < int(grid_size.x); x += 1 {
            cell_position := Vector2i32 { i32(x), i32(y) }
            if search_filter_proc(cell_position, grid_size, grid) {
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
        path, ok := find_path(grid, grid_size, { 0, 3 }, { 0, 0 }, allocator = context.temp_allocator)
        testing.expect(t, ok, "should return ok")
        testing.expect(t, slice.equal(path[:], []Vector2i32 { { 0, 3 }, { 0, 2 },  { 0, 1 }, { 0, 0 } }), "should return a valid path")
    }
    {
        path, ok := find_path(grid, grid_size, { 0, 3 }, { 1, 3 }, allocator = context.temp_allocator)
        testing.expect(t, ok, "should return ok")
        testing.expect(t, slice.equal(path[:], []Vector2i32 { { 0, 3 }, { 1, 3 } }), "should return a valid path")
    }
    {
        path, ok := find_path(grid, grid_size, { 1, 3 }, { 1, 2 }, allocator = context.temp_allocator)
        testing.expect(t, ok == false, "should return ko")
        testing.expect(t, slice.equal(path[:], []Vector2i32 { }), "should return an empty path")
    }
    {
        path, ok := find_path(grid, grid_size, { 0, 3 }, { 2, 2 }, allocator = context.temp_allocator)
        testing.expect(t, ok, "should return ok")
        testing.expect(t, slice.equal(path[:], []Vector2i32 { { 0, 3 }, { 1, 3 }, { 2, 2 } }), "should return a valid path")
    }
    {
        path, ok := find_path(grid, grid_size, { 0, 3 }, { 4, 3 }, allocator = context.temp_allocator)
        testing.expect(t, ok, "should return ok")
        testing.expect(t, slice.equal(path[:], []Vector2i32 { { 0, 3 }, { 1, 3 }, { 2, 2 }, { 3, 3 }, { 4, 3 } }), "should return a valid path")
    }
}
