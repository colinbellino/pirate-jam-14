package debug

import "core:log"
import "core:mem"
import "core:runtime"
import "core:fmt"
import "core:os"
import "core:time"

import "../engine/platform"

SNAPSHOTS_COUNT :: 120;

Debug_State :: struct {
    snapshot_index:         i32,
    timed_block_index:      i32,
    timed_block_data:       map[string]Timed_Block,

    frame_started:          time.Time,
    frame_timing:           Frame_Timing,

    alloc_infos:            map[Allocator_Id]Allocator_Info,
    current_alloc_id:       Allocator_Id,
}

Timed_Block :: struct {
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

// TODO: get debug memory from the platform
state: Debug_State;

alloc_init :: proc(id: Allocator_Id, allocator: mem.Allocator, size: int) {
    state.alloc_infos[id] = {};
    alloc_info := &state.alloc_infos[id];
    alloc_info.allocator = allocator;
    alloc_info.size = size;
    alloc_info.data = allocator.data;
    alloc_info.data_end = allocator.data;
    alloc_info.entries = make([dynamic]Allocator_Entry, 0);

    memory_start := uintptr(allocator.data);
    memory_end := uintptr(mem.ptr_offset(transmute(^u8)allocator.data, size));
    // log.debugf("[%v] %v + %v = %v", id, memory_start, size, memory_end);
    assert((memory_end - memory_start) == uintptr(size));
}

alloc_start :: proc(allocator_data: rawptr, mode: mem.Allocator_Mode, size, alignment: int, old_memory: rawptr, old_size: int, location := #caller_location) {
    allocator_id: Allocator_Id;
    for id, alloc_info in state.alloc_infos {
        if alloc_info.data == allocator_data {
            allocator_id = id;
            break;
        }
    }

    assert(allocator_id != .None);

    state.current_alloc_id = allocator_id;

    alloc_info := &state.alloc_infos[allocator_id];
    append(&alloc_info.entries, Allocator_Entry { allocator_id, allocator_data, mode, size, alignment, old_memory, old_size, location });

    if mem.ptr_offset(transmute(^u8)alloc_info.data_end, size) > mem.ptr_offset(transmute(^u8)alloc_info.data_end, alloc_info.size) {
        log.errorf("custom_allocator_proc(%v) ERROR: %v", allocator_id, mem.Allocator_Error.Out_Of_Memory);
    }
}

alloc_end :: proc(data: []u8, error: mem.Allocator_Error) {
    allocator_id :=  state.current_alloc_id;
    alloc_info := &state.alloc_infos[allocator_id];
    alloc_entry := alloc_info.entries[len(alloc_info.entries) - 1];
    using alloc_entry;

    if mode == .Alloc || mode == .Alloc_Non_Zeroed {
        alloc_info.data_end = mem.ptr_offset(transmute(^u8)alloc_info.data_end, size);
    }
    if mode == .Free {
        alloc_info.data_end = rawptr(uintptr(alloc_info.data_end) - uintptr(old_size));
    }
    if mode == .Resize {
        log.debug(".Resize not implemented");
        os.exit(1);
    }
    // log.debugf("old_memory: %p %v", old_memory, old_size);

    if error != .None {
        log.errorf("custom_allocator_proc(%v) ERROR: %v", allocator_id, error);
    }
}

format_alloc_entry :: proc(alloc_entry: Allocator_Entry) -> string {
    using alloc_entry;
    return fmt.tprintf("[%v] %v: %v -> %v", id, mode, size, location);
}

get_alloc_info :: proc(id: Allocator_Id) -> ^Allocator_Info {
    return &state.alloc_infos[id];
}

@(deferred_out=timed_block_end)
timed_block :: proc(block_name: string = "", location := #caller_location) -> ^Timed_Block {
    return timed_block_start(block_name, location);
}

timed_block_start :: proc(block_name: string = "", location := #caller_location) -> ^Timed_Block {
    // if state.profiler_enabled == false {
    //     return {};
    // }

    name := block_name;
    if name == "" {
        name = location.procedure;
    }

    block, found := &state.timed_block_data[name];
    if found == false {
        state.timed_block_data[name] = {};
        block = &state.timed_block_data[name];
    }

    block.name = name;
    block.location = location;

    snapshot := &block.snapshots[state.snapshot_index];
    snapshot.hit_count += 1;
    snapshot.start = time.now();

    return block;
}

timed_block_end :: proc(block: ^Timed_Block) {
    snapshot := &block.snapshots[state.snapshot_index];
    snapshot.end = time.now();
    snapshot.duration += time.diff(snapshot.start, snapshot.end);
}

timed_block_clear :: proc() {
    clear(&state.timed_block_data);
}

timed_block_reset :: proc(block_id: string) {
    block := &state.timed_block_data[block_id];
    block.snapshots[state.snapshot_index].duration = 0;
    block.snapshots[state.snapshot_index].hit_count = 0;
}

frame_timing_start :: proc() {
    state.frame_started = time.now();
    state.frame_timing = Frame_Timing {};
}

frame_timing_end :: proc() {
    frame_completed := time.now();
    state.frame_started = frame_completed;
    state.frame_timing.frame_completed = time.diff(state.frame_started, frame_completed);

    state.snapshot_index += 1;
    if state.snapshot_index >= SNAPSHOTS_COUNT {
        state.snapshot_index = 0;
    }

    for block_id in state.timed_block_data {
        timed_block_reset(block_id);
    }
}
