package engine

import "core:c"
import "core:mem"
import "core:fmt"
import tracy "../odin-tracy"

PROFILER_COLOR_ENGINE :: 0x550000
PROFILER_COLOR_GAME   :: 0x005500

ProfiledAllocatorData :: tracy.ProfiledAllocatorData
ZoneCtx               :: tracy.ZoneCtx

profiler_set_thread_name  :: tracy.SetThreadName
profiler_make_profiled_allocator :: tracy.MakeProfiledAllocator
profiler_message          :: tracy.Message
profiler_plot             :: tracy.Plot
profiler_frame_mark_start :: proc(name: cstring = nil) { tracy.FrameMarkStart(name) }
profiler_frame_mark_end   :: proc(name: cstring = nil) { tracy.FrameMarkEnd(name) }

@(deferred_out=profiler_zone_end)
profiler_zone :: proc(name: string, color: u32 = PROFILER_COLOR_GAME, loc := #caller_location) -> ZoneCtx {
    ctx := profiler_zone_begin(name, loc = loc)
    tracy.ZoneColor(ctx, color)
    return ctx
}
profiler_zone_begin :: proc(name: string, color: u32 = PROFILER_COLOR_GAME, loc := #caller_location) -> ZoneCtx {
    ctx := tracy.ZoneBegin(true, tracy.TRACY_CALLSTACK, loc)
    tracy.ZoneName(ctx, name)
    tracy.ZoneColor(ctx, color)
    return ctx
}
profiler_zone_end :: proc(ctx: ZoneCtx) {
    tracy.ZoneEnd(ctx)
}

@(private="file") _temp_zone: ZoneCtx
profiler_zone_temp_begin :: proc(name: string, loc := #caller_location) {
    _temp_zone = tracy.ZoneBegin(true, tracy.TRACY_CALLSTACK, loc)
    tracy.ZoneName(_temp_zone, name)
}
profiler_zone_temp_end :: proc() {
    tracy.ZoneEnd(_temp_zone)
}

ProfiledAllocatorDataNamed :: struct {
    backing_allocator:  mem.Allocator,
    profiled_allocator: mem.Allocator,
    callstack_size:     i32,
    secure:             b32,
    name:               cstring,
}
profiler_make_profiled_allocator_named :: proc(
    self: ^ProfiledAllocatorDataNamed,
    callstack_size: i32 = tracy.TRACY_CALLSTACK,
    secure: b32 = false,
    backing_allocator := context.allocator
) -> mem.Allocator {
    self.callstack_size = callstack_size
    self.secure = secure
    self.backing_allocator = backing_allocator
    self.profiled_allocator = mem.Allocator { data = self, procedure = profiled_allocator_procedure }
    return self.profiled_allocator
}
profiled_allocator_procedure :: proc(allocator_data: rawptr, mode: mem.Allocator_Mode, size, alignment: int, old_memory: rawptr, old_size: int, location := #caller_location) -> ([]byte, mem.Allocator_Error) {
    self := cast(^ProfiledAllocatorDataNamed) allocator_data
    new_memory, error := self.backing_allocator.procedure(self.backing_allocator.data, mode, size, alignment, old_memory, old_size, location)
    if error == .None {
        // fmt.printf("profiled_allocator_procedure: %v | %p | %v\n", mode, new_memory, size)
        switch mode {
            case .Alloc, .Alloc_Non_Zeroed:
                EmitAllocNamed(new_memory, size, self.callstack_size, self.secure, self.name)
            case .Free:
                EmitFreeNamed(old_memory, self.callstack_size, self.secure, self.name)
            case .Free_All:
                // NOTE: Free_All not supported by this allocator
            case .Resize:
                EmitFreeNamed(old_memory, self.callstack_size, self.secure, self.name)
                EmitAllocNamed(new_memory, size, self.callstack_size, self.secure, self.name)
            case .Query_Info:
                // TODO
            case .Query_Features:
                // TODO
        }
    }
    return new_memory, error
}
@(private="file")
EmitAllocNamed :: #force_inline proc(new_memory: []byte, size: int, callstack_size: i32, secure: b32, name: cstring) {
    when tracy.TRACY_HAS_CALLSTACK {
        if callstack_size > 0 {
            tracy.___tracy_emit_memory_alloc_callstack_named(raw_data(new_memory), c.size_t(size), callstack_size, secure, name)
        } else {
            tracy.___tracy_emit_memory_alloc_named(raw_data(new_memory), c.size_t(size), secure, name)
        }
    } else {
        tracy.___tracy_emit_memory_alloc_named(raw_data(new_memory), c.size_t(size), secure, name)
    }
}

@(private="file")
EmitFreeNamed :: #force_inline proc(old_memory: rawptr, callstack_size: i32, secure: b32, name: cstring) {
    if old_memory == nil { return }
    when tracy.TRACY_HAS_CALLSTACK {
        if callstack_size > 0 {
            tracy.___tracy_emit_memory_free_callstack_named(old_memory, callstack_size, secure, name)
        } else {
            tracy.___tracy_emit_memory_free_named(old_memory, secure, name)
        }
    } else {
        tracy.___tracy_emit_memory_free_named(old_memory, secure, name)
    }
}
