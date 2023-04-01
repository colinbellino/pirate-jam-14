package engine

import "core:mem"
import "core:runtime"
import "core:time"

import tracy "../odin-tracy"

TRACY_ENABLE :: #config(TRACY_ENABLE, false);

Debug_State :: struct {
    allocator:   mem.Allocator,
    last_reload: time.Time,
}

ProfiledAllocatorData :: tracy.ProfiledAllocatorData;

debug_init :: proc(allocator: mem.Allocator) -> (debug_state: ^Debug_State) {
    debug_state = new(Debug_State, allocator);
    debug_state.allocator = allocator;
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
