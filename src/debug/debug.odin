package debug

import "core:fmt"
import "core:log"
import "core:mem"
import "core:runtime"
import "core:time"

import "../engine/renderer"

SNAPSHOTS_COUNT :: 120;
GRAPH_COLORS :: []renderer.Color {
    { 255, 0, 0, 255 },
    { 0, 255, 0, 255 },
    { 255, 255, 0, 255 },
    { 0, 0, 255, 255 },
    { 255, 0, 255, 255 },
    { 0, 255, 255, 255 },
    { 255, 255, 255, 255 },
};
TIMED_BLOCK_MAX :: 99;

Debug_State :: struct {
    allocator:              runtime.Allocator,
    running:                bool,
    snapshot_index:         i32,
    timed_block_index:      i32,
    timed_block_data:       map[int]^Timed_Block,

    frame_started:          time.Time,
    frame_timings:          [SNAPSHOTS_COUNT]Frame_Timing,

    alloc_infos:            map[Allocator_Id]Allocator_Info,
    current_alloc_id:       Allocator_Id,
}

Timed_Block :: struct {
    id:                 int,
    name:               string,
    location:           runtime.Source_Code_Location,
    snapshots:          [SNAPSHOTS_COUNT]Timed_Block_Snapshot,
}

Timed_Block_Snapshot :: struct {
    // TODO: we need only duration and hit_count
    start:              time.Time,
    end:                time.Time,
    duration:           time.Duration,
    hit_count:          i32,
}

Frame_Timing :: struct {
    input_processed:            time.Duration,
    game_updated:               time.Duration,
    framerate_wait_completed:   time.Duration,
    frame_completed:            time.Duration,
}

Allocator_Id :: enum { None, App, Platform, Renderer, Game }

Allocator_Info :: struct {
    allocator:      mem.Allocator,
    size:           int,
    data:           rawptr,
    data_end:       rawptr,
    entries:        [dynamic]Allocator_Entry,
}

Allocator_Entry :: struct {
    id:             Allocator_Id,
    data:           rawptr,
    mode:           mem.Allocator_Mode,
    size:           int,
    alignment:      int,
    old_memory:     rawptr,
    old_size:       int,
    location:       runtime.Source_Code_Location,
}

debug_init :: proc(allocator: mem.Allocator) -> (debug_state: ^Debug_State) {
    debug_state = new(Debug_State, allocator);
    debug_state.allocator = allocator;
    // debug_state.timed_block_data = make(map[string]^Timed_Block, 64, allocator);
    debug_state.running = true;
    return;
}

// alloc_init :: proc(id: Allocator_Id, allocator: mem.Allocator, size: int) {
//     _state.alloc_infos[id] = {};
//     alloc_info := &_state.alloc_infos[id];
//     alloc_info.allocator = allocator;
//     alloc_info.size = size;
//     alloc_info.data = allocator.data;
//     alloc_info.data_end = allocator.data;
//     alloc_info.entries = make([dynamic]Allocator_Entry, 0);

//     memory_start := uintptr(allocator.data);
//     memory_end := uintptr(mem.ptr_offset(transmute(^u8)allocator.data, size));
//     assert((memory_end - memory_start) == uintptr(size));
//     // log.debugf("[%v] %v + %v = %v", id, memory_start, size, memory_end);
// }

// alloc_start :: proc(allocator_data: rawptr, mode: mem.Allocator_Mode, size, alignment: int, old_memory: rawptr, old_size: int, location := #caller_location) {
//     allocator_id: Allocator_Id;
//     for id, alloc_info in _state.alloc_infos {
//         if alloc_info.data == allocator_data {
//             allocator_id = id;
//             break;
//         }
//     }

//     assert(allocator_id != .None);

//     _state.current_alloc_id = allocator_id;

//     alloc_info := &_state.alloc_infos[allocator_id];
//     append(&alloc_info.entries, Allocator_Entry { allocator_id, allocator_data, mode, size, alignment, old_memory, old_size, location });

//     if mem.ptr_offset(transmute(^u8)alloc_info.data_end, size) > mem.ptr_offset(transmute(^u8)alloc_info.data_end, alloc_info.size) {
//         log.errorf("custom_allocator_proc(%v) ERROR: %v", allocator_id, mem.Allocator_Error.Out_Of_Memory);
//     }
// }

// alloc_end :: proc(data: []u8, error: mem.Allocator_Error) {
//     allocator_id :=  _state.current_alloc_id;
//     alloc_info := &_state.alloc_infos[allocator_id];
//     alloc_entry := alloc_info.entries[len(alloc_info.entries) - 1];
//     using alloc_entry;

//     if mode == .Alloc || mode == .Alloc_Non_Zeroed {
//         alloc_info.data_end = mem.ptr_offset(transmute(^u8)alloc_info.data_end, size);
//     }
//     if mode == .Free {
//         alloc_info.data_end = rawptr(uintptr(alloc_info.data_end) - uintptr(old_size));
//     }
//     if mode == .Resize {
//         log.warn(".Resize not implemented in debug.alloc_end");
//     }
//     // log.debugf("old_memory: %p %v", old_memory, old_size);

//     if error != .None {
//         log.errorf("custom_allocator_proc(%v) ERROR: %v", allocator_id, error);
//     }
// }

// format_alloc_entry :: proc(alloc_entry: Allocator_Entry) -> string {
//     using alloc_entry;
//     return fmt.tprintf("[%v] %v: %v -> %v", id, mode, size, location);
// }

// get_alloc_info :: proc(id: Allocator_Id) -> ^Allocator_Info {
//     return &_state.alloc_infos[id];
// }

@(deferred_out=timed_block_end)
timed_block :: proc(debug_state: ^Debug_State, block_id: int, location := #caller_location) -> (^Debug_State, int) {
    return debug_state, timed_block_begin(debug_state, block_id, location);
}

timed_block_begin :: proc(debug_state: ^Debug_State, block_id: int, location := #caller_location) -> int {
    context.allocator = debug_state.allocator;
    block, found := debug_state.timed_block_data[block_id];
    if found == false {
        block = new(Timed_Block);
        // log.warnf("timed_block_data not found: %v", block_id);
    }

    // block.name = block_name;
    block.id = block_id;
    block.location = location;

    snapshot := &block.snapshots[debug_state.snapshot_index];
    snapshot.hit_count += 1;
    snapshot.start = time.now();

    debug_state.timed_block_data[block_id] = block;

    return block_id;
}

timed_block_end :: proc(debug_state: ^Debug_State, block_id: int) {
    context.allocator = debug_state.allocator;
    if debug_state.running == false { return; }

    block := debug_state.timed_block_data[block_id];
    snapshot := &block.snapshots[debug_state.snapshot_index];
    snapshot.end = time.now();
    snapshot.duration = time.diff(snapshot.start, snapshot.end);
}

timed_block_reset :: proc(debug_state: ^Debug_State, block_id: string) {
    // block := &debug_state.timed_block_data[block_id];
    // block.active = false;
    // for snapshot, index in block.snapshots {
    //     block.snapshots[index].duration = 0;
    //     block.snapshots[index].hit_count = 0;
    // }
}

frame_timing_start :: proc(debug_state: ^Debug_State) {
    context.allocator = debug_state.allocator;
    if debug_state.running == false { return; }

    debug_state.frame_started = time.now();
    frame_timing := &debug_state.frame_timings[debug_state.snapshot_index];
    frame_timing^ = Frame_Timing {};
}

frame_timing_end :: proc(debug_state: ^Debug_State) {
    context.allocator = debug_state.allocator;
    if debug_state.running == false { return; }

    frame_completed := time.now();
    debug_state.frame_started = frame_completed;
    frame_timing := &debug_state.frame_timings[debug_state.snapshot_index];
    frame_timing.frame_completed = time.diff(debug_state.frame_started, frame_completed);

    debug_state.snapshot_index += 1;
    if debug_state.snapshot_index >= SNAPSHOTS_COUNT {
        debug_state.snapshot_index = 0;
    }

    // for block_id in debug_state.timed_block_data {
    //     timed_block_reset(block_id);
    // }
}

Statistic :: struct {
    min:        f64,
    max:        f64,
    average:    f64,
    count:      i32,
    total:      f64,
}

statistic_begin :: proc(stat: ^Statistic) {
    stat.min = max(f64);
    stat.max = min(f64);
    stat.average = 0.0;
    stat.count = 0;
    stat.total = 0.0;
}

statistic_accumulate :: proc(stat: ^Statistic, value: f64) {
    stat.count += 1;

    if stat.min > value {
        stat.min = value;
    }

    if stat.max < value {
        stat.max = value;
    }

    stat.average += value;
    stat.total += value;
}

statistic_end :: proc(stat: ^Statistic) {
    if stat.count > 0 {
        stat.average /= f64(stat.count);
    } else {
        stat.min = 0.0;
        stat.max = 0.0;
    }
}

draw_timers :: proc(debug_state: ^Debug_State, renderer_state: ^renderer.Renderer_State, target_fps: time.Duration, window_size: renderer.Vector2i) {
    context.allocator = debug_state.allocator;
    if renderer.ui_window(renderer_state, "Timers", { 0, 0, window_size.x, window_size.y }, { .NO_TITLE, .NO_FRAME, .NO_INTERACT }) {
        renderer.ui_layout_row(renderer_state, { -1 }, 0);
        renderer.ui_label(renderer_state, fmt.tprintf("snapshot_index: %i", debug_state.snapshot_index));

        {
            for block_index := 0; block_index <= TIMED_BLOCK_MAX; block_index += 1 {
                block, found := debug_state.timed_block_data[block_index];

                if found == false {
                    continue;
                }

                current_snapshot := &block.snapshots[debug_state.snapshot_index];
                height : i32 = 30;
                colors := GRAPH_COLORS;

                renderer.ui_layout_row(renderer_state, { 300, 50, 200, SNAPSHOTS_COUNT }, height);
                block_name := fmt.tprintf("%v:(%i) %v", block.location.file_path, block.location.line, block.location.procedure);
                // block_name := fmt.tprintf("%v", block.name);
                if block.id == TIMED_BLOCK_MAX {
                    block_name = "TOTAL";
                }
                renderer.ui_label(renderer_state, block_name);
                renderer.ui_label(renderer_state, fmt.tprintf("%i", current_snapshot.hit_count));
                renderer.ui_label(renderer_state, fmt.tprintf("%fms / %fms",
                    time.duration_milliseconds(time.Duration(i64(current_snapshot.duration))),
                    time.duration_milliseconds(target_fps),
                ));
                draw_timed_block_graph(debug_state, renderer_state, block, height - 5, f64(target_fps), colors[block_index % len(GRAPH_COLORS)]);
            }
        }

        {
            values := make([][]f64, SNAPSHOTS_COUNT, context.temp_allocator);
            for snapshot_index in 0 ..< SNAPSHOTS_COUNT {
                snapshot_values := make([]f64, len(debug_state.timed_block_data), context.temp_allocator);
                block_index := 0;
                for _, block in debug_state.timed_block_data {
                    defer block_index += 1;

                    if block.id == TIMED_BLOCK_MAX {
                        continue;
                    }

                    value := block.snapshots[snapshot_index];
                    snapshot_values[block_index] = f64(value.duration);
                }

                values[snapshot_index] = snapshot_values;
            }

            height : i32 = 200;
            width : i32 = SNAPSHOTS_COUNT * 6;
            renderer.ui_stacked_graph(renderer_state, values, width, height, f64(target_fps), debug_state.snapshot_index, GRAPH_COLORS);
        }
    }
}

draw_timed_block_graph :: proc(debug_state: ^Debug_State, renderer_state: ^renderer.Renderer_State, block: ^Timed_Block, height: i32, max_value: f64, color: renderer.Color) {
    values := make([]f64, SNAPSHOTS_COUNT, context.temp_allocator);
    stat_hit_count: Statistic;
    stat_duration: Statistic;
    statistic_begin(&stat_hit_count);
    statistic_begin(&stat_duration);
    for snapshot, index in block.snapshots {
        statistic_accumulate(&stat_hit_count, f64(snapshot.hit_count));
        statistic_accumulate(&stat_duration, f64(snapshot.duration));
        values[index] = f64(snapshot.duration);
    }
    statistic_end(&stat_hit_count);
    statistic_end(&stat_duration);

    renderer.ui_graph(renderer_state, values, SNAPSHOTS_COUNT, height, max_value, debug_state.snapshot_index, color);
}
