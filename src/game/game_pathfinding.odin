package game

import "core:log"
import "core:math"
import "core:slice"
import "../engine"

Node :: struct {
    cell:               Grid_Cell,
    local_position:     Vector2i32,
    position:           Vector2i32,
    g_cost:             i32,
    h_cost:             i32,
    parent:             ^Node,
}

generate_levels_nodes :: proc() {
    clear(&_mem.game.play.nodes)

    for level in _mem.game.play.levels {
        for y := 0; y < int(level.size.y); y += 1 {
            for x := 0; x < int(level.size.x); x += 1 {
                local_position := Vector2i32 { i32(x), i32(y) }
                global_position := level.position + local_position
                cell_index := engine.grid_position_to_index(local_position, level.size.x)
                node := Node {
                    cell            = level.grid[cell_index],
                    local_position  = local_position,
                    position        = global_position,
                }
                _mem.game.play.nodes[global_position] = node
                // log.debugf("node: %v", node)
            }
        }
    }
}

CARDINAL_DIRECTIONS :: []Vector2i32 {
    { 1, 0 },
    { 0, 1 },
    { -1, 0 },
    { 0, -1 },
}
MAX_ITERATION :: 999

find_path :: proc(start_position, end_position: Vector2i32, allocator := context.allocator) -> ([]Vector2i32, bool) #optional_ok {
    engine.profiler_zone("find_path")
    nodes := _mem.game.play.nodes
    context.allocator = context.temp_allocator

    if start_position in nodes == false || end_position in nodes == false {
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

        neighbours := get_node_neighbours(nodes, current, CARDINAL_DIRECTIONS)
        for neighbour in neighbours {
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
