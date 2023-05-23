package engine

import "core:mem"
import "core:c"
import "core:time"

import tracy "../odin-tracy"

Debug_State :: struct {
    allocator:              mem.Allocator,
    last_reload:            time.Time,
    file_watches:           [200]File_Watch,
    file_watches_count:     int,
    start_game:             bool,
    save_memory:            int,
    load_memory:            int,
    game_counter:           int,
}

ProfiledAllocatorData :: tracy.ProfiledAllocatorData;

debug_init :: proc(allocator := context.allocator) -> (debug: ^Debug_State) {
    context.allocator = allocator;
    debug = new(Debug_State, allocator);
    debug.allocator = allocator;
    return;
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

@(private="file")
_tracy_emit_alloc :: #force_inline proc(new_memory: []byte, size: int, callstack_size: i32, secure: b32) {
	when tracy.TRACY_HAS_CALLSTACK {
		if callstack_size > 0 {
			tracy.___tracy_emit_memory_alloc_callstack(raw_data(new_memory), c.size_t(size), callstack_size, secure)
		} else {
			tracy.___tracy_emit_memory_alloc(raw_data(new_memory), c.size_t(size), secure)
		}
	} else {
		tracy.___tracy_emit_memory_alloc(raw_data(new_memory), c.size_t(size), secure)
	}
}

@(private="file")
_tracy_emit_free :: #force_inline proc(old_memory: rawptr, callstack_size: i32, secure: b32) {
	if old_memory == nil { return }
	when tracy.TRACY_HAS_CALLSTACK {
		if callstack_size > 0 {
			tracy.___tracy_emit_memory_free_callstack(old_memory, callstack_size, secure)
		} else {
			tracy.___tracy_emit_memory_free(old_memory, secure)
		}
	} else {
		tracy.___tracy_emit_memory_free(old_memory, secure)
	}
}
