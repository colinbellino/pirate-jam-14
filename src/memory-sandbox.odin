package main

// import "core:log"
// import "core:mem"
// import "core:os"
// import "core:runtime"

// import "memory"

// APP_ARENA_PATH          :: "state.mem";
// ARENA_SIZE_APP          :: 16;

// State :: struct {
//     pouet:              i8,
//     bla:                i8,
// }

// App :: struct {
//     arena:              mem.Arena,
//     state:              ^State,
// }

// app : App = App {};
// tracking_allocator : mem.Tracking_Allocator;

// main :: proc() {
//     options := log.Options { .Level, .Time, .Short_File_Path, .Line, .Terminal_Color };
//     context.logger = log.create_console_logger(runtime.Logger_Level.Debug, options);

//     default_allocator := runtime.Allocator { memory.custom_allocator_proc, nil };
//     mem.tracking_allocator_init(&tracking_allocator, default_allocator);
//     context.allocator = mem.tracking_allocator(&tracking_allocator);

//     {
//         buffer := make([]u8, ARENA_SIZE_APP);
//         defer delete(buffer);
//         mem.arena_init(&app.arena, buffer);
//     }

//     app_allocator := mem.Allocator { memory.custom_arena_allocator_proc, &app.arena };
//     // context.allocator = app_allocator;

//     app.state = new(State, app_allocator);

//     if len(os.args) > 1 && os.args[1] == "save" {
//         app.state.pouet = 12;
//         app.state.bla = 34;
//         memory.save_arena_to_file(APP_ARENA_PATH, &app.arena);
//     }
//     else if len(os.args) > 1 && os.args[1] == "load" {
//         memory.load_arena_from_file(APP_ARENA_PATH, &app.arena);
//     }

//     log.debugf("arena:     %p | %v", &app.arena, app.arena);
//     log.debugf("state:     %p | %v", &app.state, app.state);
//     log.info("done!");

//     for _, leak in tracking_allocator.allocation_map {
//         log.warnf("Leaked %v bytes at %v.", leak.size, leak.location);
//     }
//     for bad_free in tracking_allocator.bad_free_array {
//         log.warnf("Allocation %p was freed badly at %v.", bad_free.location, bad_free.memory);
//     }
// }
