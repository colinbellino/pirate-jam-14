package engine

import "core:mem"
import "core:runtime"
import "core:time"

import tracy "../odin-tracy"

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

ProfiledAllocatorData :: tracy.ProfiledAllocatorData;

debug_init :: proc(allocator: mem.Allocator) -> (debug_state: ^Debug_State) {
    debug_state = new(Debug_State, allocator);
    debug_state.allocator = allocator;
    // debug_state.timed_block_data = make(map[string]^Timed_Block, 64, allocator);
    debug_state.running = true;
    return;
}

profiler_make_allocator :: proc(data: ^ProfiledAllocatorData) -> mem.Allocator {
    return tracy.MakeProfiledAllocator(
        self              = data,
        callstack_size    = 5,
        backing_allocator = context.allocator,
        secure            = true,
    );
}

profiler_set_thread_name :: proc(name: cstring) {
    tracy.SetThreadName(name);
}

profiler_frame_mark :: proc() {
    tracy.FrameMark();
}

@(deferred_out=profiler_zone_end)
profiler_zone_name :: proc(name: string) -> tracy.ZoneCtx {
    return profiler_zone_begin(name);
}

@(deferred_out=profiler_zone_end)
profiler_zone_name_color :: proc(name: string, color: u32) -> tracy.ZoneCtx {
    ctx := profiler_zone_begin(name);
    tracy.ZoneColor(ctx, color);
    return ctx;
}

profiler_zone :: proc {
    profiler_zone_name,
    profiler_zone_name_color,
}

profiler_zone_begin :: proc(name: string) -> tracy.ZoneCtx {
    ctx := tracy.ZoneBegin(true, tracy.TRACY_CALLSTACK);
    tracy.ZoneName(ctx, name);
    return ctx;
}

profiler_zone_end :: proc(ctx: tracy.ZoneCtx) {
    tracy.ZoneEnd(ctx);
}
