package engine2

// import "core:c"
// import "core:mem"
// import tracy "../odin-tracy"

// PROFILER_COLOR_ENGINE :: 0x550000
// PROFILER_COLOR_GAME   :: 0x005500

// Tracy_Zone_Ctx           :: tracy.ZoneCtx
// Tracy_Allocator_Data     :: tracy.ProfiledAllocatorData

// tracy_set_thread_name :: proc(name: cstring) {
//     tracy.SetThreadName(name)
// }

// tracy_make_profiled_allocator :: proc(data: ^Tracy_Allocator_Data, backing_allocator: mem.Allocator) -> mem.Allocator {
//     return tracy.MakeProfiledAllocator(
//         self              = data,
//         backing_allocator = backing_allocator,
//     )
// }

// tracy_message :: proc(message: string) {
//     tracy.Message(message)
// }

// tracy_plot :: proc(message: cstring, value: f64) {
//     tracy.Plot(message, value)
// }

// tracy_frame_mark :: proc(name: cstring = nil) {
//     tracy.FrameMark(name)
// }
// tracy_frame_mark_start :: proc(name: cstring = nil) {
//     tracy.FrameMarkStart(name)
// }
// tracy_frame_mark_end :: proc(name: cstring = nil) {
//     tracy.FrameMarkEnd(name)
// }
