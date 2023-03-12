package engine

import "core:fmt"
import "core:mem"
import "core:runtime"
import "core:time"

SNAPSHOTS_COUNT :: 120;
GRAPH_COLORS :: []Color {
    { 255, 0, 0, 255 },
    { 0, 255, 0, 255 },
    { 255, 255, 0, 255 },
    { 0, 0, 255, 255 },
    { 255, 0, 255, 255 },
    { 0, 255, 255, 255 },
    { 255, 255, 255, 255 },
};
TIMED_BLOCK_MAX :: 20;

Debug_State :: struct {
    allocator:              runtime.Allocator,
    running:                bool,
    snapshot_index:         i32,
    timed_block_index:      i32,
    timed_block_data:       [TIMED_BLOCK_MAX + 1]^Timed_Block,

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
timed_block :: proc(debug_state: ^Debug_State, block_name: string, location := #caller_location) -> (^Debug_State, string) {
    return debug_state, timed_block_begin(debug_state, block_name, location);
}

timed_block_begin :: proc(debug_state: ^Debug_State, block_name: string, location := #caller_location) -> string {
    context.allocator = debug_state.allocator;

    block_id := -1;
    last_block_id := -1;
    for i in 0..<len(debug_state.timed_block_data) {
        block := debug_state.timed_block_data[i];
        if block != nil {
            if block.name == block_name {
                block_id = i;
                break;
            }

            last_block_id += 1;
        }
    }

    block : ^Timed_Block;
    if block_id == -1 {
        block = new(Timed_Block);
        block.id = last_block_id + 1;
    } else {
        block = debug_state.timed_block_data[block_id];
    }

    block.name = block_name;
    block.location = location;

    snapshot := &block.snapshots[debug_state.snapshot_index];
    snapshot.hit_count += 1;
    snapshot.start = time.now();

    debug_state.timed_block_data[block.id] = block;

    return block.name;
}

timed_block_end :: proc(debug_state: ^Debug_State, block_name: string) {
    context.allocator = debug_state.allocator;
    if debug_state.running == false { return; }

    block_id := -1;
    for i in 0..<len(debug_state.timed_block_data) {
        block := debug_state.timed_block_data[i];
        if block != nil && block.name == block_name {
            block_id = i;
            break;
        }
    }
    assert(block_id > -1, fmt.tprintf("Timed_Block not found: %v", block_name));

    block := debug_state.timed_block_data[block_id];
    snapshot := &block.snapshots[debug_state.snapshot_index];
    snapshot.end = time.now();
    snapshot.duration = time.diff(snapshot.start, snapshot.end);
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
}
