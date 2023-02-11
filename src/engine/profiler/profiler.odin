package engine_profiler

import "core:log"
import "core:time"
import "core:strings"
import "core:fmt"

Record :: struct {
    start:      [dynamic]i64,
    end:        [dynamic]i64,
    average:    f32,
    count:      i64,
}

@private records : map[string]Record;

profiler_start :: proc(id: string) {
    record, exists := records[id];
    if exists == false {
        record = Record {};
    }
    append(&record.start, time.time_to_unix_nano(time.now()));
    records[id] = record;
}

profiler_end :: proc(id: string, print: bool = false) {
    record := records[id];
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
    records[id] = record;
}

profiler_print_all :: proc() {
    line1 := strings.builder_make();
    line2 := strings.builder_make();
    line3 := strings.builder_make();
    strings.write_string(&line1, "| Record          | ");
    strings.write_string(&line2, "| Frame   (in ms) | ");
    strings.write_string(&line3, "| Average (in ms) | ");

    for id in records {
        record := records[id];

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
}
