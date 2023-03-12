package engine

import "core:fmt"
import "core:log"
import "core:math"
import "core:mem"
import "core:os"
import "core:slice"
import "core:strings"
import "core:time"

Record :: struct {
    start:      [dynamic]i64,
    end:        [dynamic]i64,
    average:    f32,
    count:      i64,
}

Memory_Marker :: struct #packed {
    a0:     u8,
    a1:     u8,
    a2:     u8,
    a3:     u8,
    a4:     u8,
    a5:     u8,
    a6:     u8,
    a7:     u8,
    a8:     u8,
    a9:     u8,
    a10:     u8,
    a11:     u8,
    a12:     u8,
    a13:     u8,
    a14:     u8,
    a15:     u8,
}

@(private="file") _records : map[string]Record;

profiler_start :: proc(id: string) {
    if contains_os_args("no-profiler") {
        return;
    }

    record, exists := _records[id];
    // assert(exists == false, fmt.tprintf("Profiling record already exists: %v", id));
    if exists == false {
        record = Record {};
    }
    append(&record.start, time.time_to_unix_nano(time.now()));
    _records[id] = record;
}

profiler_end :: proc(id: string, print: bool = false) {
    if contains_os_args("no-profiler") {
        return;
    }

    if id in _records == false {
        return;
    }

    record := _records[id];
    append(&record.end, time.time_to_unix_nano(time.now()));
    record.average = 0;
    record.count += 1;
    for i := 0; i < int(record.count); i += 1 {
        duration := f32(record.end[i] - record.start[i]);
        record.average += duration;
    }
    record.average /= f32(record.count);
    duration := record.end[record.count - 1] - record.start[record.count - 1];
    if print {
        log.debugf("PROFILER: %v -> %vms", id, f32(duration) / 1_000_000);
    }
    _records[id] = record;
}

profiler_print_all :: proc() {
    if contains_os_args("no-profiler") {
        return;
    }

    line1 := strings.builder_make();
    line2 := strings.builder_make();
    line3 := strings.builder_make();
    strings.write_string(&line1, "| Record          | ");
    strings.write_string(&line2, "| Frame   (in ms) | ");
    strings.write_string(&line3, "| Average (in ms) | ");

    for id in _records {
        record := _records[id];

        assert(record.count > 0, "Record count == 0");

        strings.write_string(&line1, id);
        strings.write_string(&line1, " | ");

        duration := record.end[record.count - 1] - record.start[record.count - 1];
        duration_str := fmt.tprintf("%v", f32(duration) / 1_000_000);
        strings.write_string(&line2, duration_str);
        if len(duration_str) < len(id) {
            for i := 0; i < len(id) - len(duration_str); i += 1 {
                strings.write_byte(&line2, ' ');
            }
        }
        strings.write_string(&line2, " | ");

        avegage := record.average;
        average_str := fmt.tprintf("%v", f32(avegage) / 1_000_000);
        strings.write_string(&line3, average_str);
        if len(average_str) < len(id) {
            for i := 0; i < len(id) - len(average_str); i += 1 {
                strings.write_byte(&line3, ' ');
            }
        }
        strings.write_string(&line3, " | ");
    }

    log.debug(fmt.tprintf("\n%v\n%v\n%v", strings.to_string(line1), strings.to_string(line2), strings.to_string(line3)));

    clear(&_records);
}


profiler_arena_allocator_proc :: proc(
    allocator_data: rawptr, mode: mem.Allocator_Mode,
    size, alignment: int,
    old_memory: rawptr, old_size: int, location := #caller_location,
) -> (result: []byte, error: mem.Allocator_Error) {
    result, error = profiler_custom_arena_allocator_proc(allocator_data, mode, size, alignment, old_memory, old_size, location);

    arena := cast(^mem.Arena)allocator_data;
    arena_name: Arena_Name;
    if len(arena.data) > 0 {
        arena_name = cast(Arena_Name)arena.data[0];
    }

    if contains_os_args("log-alloc") {
        ptr := mode == .Free ? old_memory : rawptr(&result);
        fmt.printf("[%v] %v %v byte (%p) at %v\n", arena_name, mode, size, ptr, location);
    }

    if error != .None && error != .Mode_Not_Implemented {
        fmt.eprintf("[%v] ERROR %v: %v byte at %v\n", arena_name, error, size, location);
        os.exit(0);
    }

    return;
}

@(private="file")
profiler_custom_arena_allocator_proc :: proc(
    allocator_data: rawptr, mode: mem.Allocator_Mode,
    size, alignment: int,
    old_memory: rawptr, old_size: int, location := #caller_location,
) -> ([]byte, mem.Allocator_Error)  {
    arena := cast(^mem.Arena)allocator_data;

    switch mode {
        case .Alloc, .Alloc_Non_Zeroed:
            #no_bounds_check end := &arena.data[arena.offset];

            ptr := mem.align_forward(end, uintptr(alignment));

            total_size := size + mem.ptr_sub((^byte)(ptr), (^byte)(end));

            if arena.offset + total_size > len(arena.data) {
                return nil, .Out_Of_Memory;
            }

            arena.offset += total_size;
            arena.peak_used = max(arena.peak_used, arena.offset);
            if mode != .Alloc_Non_Zeroed {
                mem.zero(ptr, size);
            }
            return mem.byte_slice(ptr, size), nil;

        case .Free:
            return nil, .Mode_Not_Implemented;

        case .Free_All:
            arena.offset = size_of(Arena_Name); // Important: we want to keep the arena name which is always first

        case .Resize:
            return mem.default_resize_bytes_align(mem.byte_slice(old_memory, old_size), size, alignment, mem.arena_allocator(arena));

        case .Query_Features:
            set := (^mem.Allocator_Mode_Set)(old_memory);
            if set != nil {
                set^ = {.Alloc, .Alloc_Non_Zeroed, .Free_All, .Resize, .Query_Features};
            }
            return nil, nil;

        case .Query_Info:
            return nil, .Mode_Not_Implemented;
        }

    return nil, nil;
}
