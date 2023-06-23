package engine

import "core:c"
import "core:mem"

PROFILER :: #config(PROFILER, ODIN_DEBUG)

when PROFILER {
    import tracy "../odin-tracy"

    ProfiledAllocatorData :: tracy.ProfiledAllocatorData
    ZoneCtx :: tracy.ZoneCtx

    profiler_make_profiled_allocator :: proc(data: ^ProfiledAllocatorData, arena_allocator: mem.Allocator) -> mem.Allocator {
        return tracy.MakeProfiledAllocator(
            self              = data,
            backing_allocator = arena_allocator,
        )
    }

    profiler_set_thread_name :: proc(name: cstring) {
        tracy.SetThreadName(name)
    }

    profiler_frame_mark :: proc(name: cstring = nil) {
        tracy.FrameMark(name)
    }
    profiler_frame_mark_start :: proc(name: cstring) {
        tracy.FrameMarkStart(name)
    }
    profiler_frame_mark_end :: proc(name: cstring) {
        tracy.FrameMarkEnd(name)
    }

    @(deferred_out=profiler_zone_end)
    profiler_zone_name :: proc(name: string) -> ZoneCtx {
        return profiler_zone_begin(name)
    }

    @(deferred_out=profiler_zone_end)
    profiler_zone_name_color :: proc(name: string, color: u32) -> ZoneCtx {
        ctx := profiler_zone_begin(name)
        tracy.ZoneColor(ctx, color)
        return ctx
    }

    profiler_zone_begin :: proc(name: string) -> ZoneCtx {
        // fmt.printf("zone_begin: %v\n", name)
        ctx := tracy.ZoneBegin(true, tracy.TRACY_CALLSTACK)
        tracy.ZoneName(ctx, name)
        return ctx
    }

    profiler_zone_end :: proc(ctx: ZoneCtx) {
        // fmt.printf("zone_end\n")
        tracy.ZoneEnd(ctx)
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
        if old_memory == nil {
            return
        }
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
} else {
    ProfiledAllocatorData :: struct {
        backing_allocator: mem.Allocator,
    }
    ZoneCtx :: struct {}
    profiler_make_profiled_allocator :: proc(data: ^ProfiledAllocatorData, arena_allocator: mem.Allocator) -> (result: mem.Allocator) { return }
    profiler_set_thread_name :: proc(name: cstring) { }
    profiler_frame_mark :: proc(name: cstring = nil) { }
    profiler_frame_mark_start :: proc(name: cstring) { }
    profiler_frame_mark_end :: proc(name: cstring) { }
    profiler_zone_name :: proc(name: string) -> (result: ZoneCtx) { return }
    profiler_zone_name_color :: proc(name: string, color: u32) -> (result: ZoneCtx) { return }
    profiler_zone_begin :: proc(name: string) -> (result: ZoneCtx) { return }
    profiler_zone_end :: proc(ctx: ZoneCtx) { }
}

profiler_zone :: proc {
    profiler_zone_name,
    profiler_zone_name_color,
}
