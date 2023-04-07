package engine

import "core:mem"
import "core:time"
import "core:log"
import "core:c"

import tracy "../odin-tracy"

TRACY_ENABLE :: #config(TRACY_ENABLE, false);

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

profiler_emit_alloc :: proc(old_memory: rawptr, new_memory: []byte, mode: mem.Allocator_Mode, size: int, error: mem.Allocator_Error) {
    callstack_size: i32 = tracy.TRACY_CALLSTACK;
    secure: b32 = false;

    if error == .None {
        switch mode {
            case .Alloc, .Alloc_Non_Zeroed: {
                // FIXME: this isn't working correctly and is crashing tracy, we might not be passing the right pointers
                _tracy_emit_alloc(new_memory, size, callstack_size, secure);
            }
            case .Free: {
                // _tracy_emit_free(old_memory, callstack_size, secure);
            }
            case .Free_All: {
                // FIXME:
            }
            case .Resize: {
                // _tracy_emit_free(old_memory, callstack_size, secure);
                // _tracy_emit_alloc(new_memory, size, callstack_size, secure);
            }
            case .Query_Info: {}
            case .Query_Features: {}
        }
    }
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
