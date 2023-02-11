package engine_profiler

import "core:log"
import "core:time"

@private start_timestamp : i64;

profiler_start :: proc(id: string) {
    start_timestamp = time.time_to_unix_nano(time.now());
}

profiler_end :: proc(id: string) {
    duration := time.time_to_unix_nano(time.now()) - start_timestamp;
    log.debugf("PROFILER: %v -> %vms", id, f32(duration) / 1_000_000);
}
