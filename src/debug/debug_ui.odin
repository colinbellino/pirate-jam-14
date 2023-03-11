package debug

import "core:fmt"
import "core:time"
import "core:log"

import "../engine/renderer"

draw_timers :: proc(debug_state: ^Debug_State, renderer_state: ^renderer.Renderer_State, target_fps: time.Duration, window_size: renderer.Vector2i) {
    context.allocator = debug_state.allocator;
    if renderer.ui_window(renderer_state, "Timers", { 0, 0, window_size.x, window_size.y }, { .NO_TITLE, .NO_FRAME, .NO_INTERACT }) {
        renderer.ui_layout_row(renderer_state, { -1 }, 0);
        renderer.ui_label(renderer_state, fmt.tprintf("snapshot_index: %i", debug_state.snapshot_index));

        {
            for block_index := 0; block_index <= TIMED_BLOCK_MAX; block_index += 1 {
                block := debug_state.timed_block_data[block_index];

                if block == nil || block.name == "total" {
                    continue;
                }

                current_snapshot := &block.snapshots[debug_state.snapshot_index];
                height : i32 = 30;
                colors := GRAPH_COLORS;

                renderer.ui_layout_row(renderer_state, { 300, 50, 200, SNAPSHOTS_COUNT }, height);
                // block_name := fmt.tprintf("%v:(%i) %v", block.location.file_path, block.location.line, block.location.procedure);
                block_name := fmt.tprintf("%v", block.name);
                renderer.ui_label(renderer_state, block_name);
                renderer.ui_label(renderer_state, fmt.tprintf("%i", current_snapshot.hit_count));
                renderer.ui_label(renderer_state, fmt.tprintf("%fms / %fms",
                    time.duration_milliseconds(time.Duration(i64(current_snapshot.duration))),
                    time.duration_milliseconds(target_fps),
                ));
                draw_timed_block_graph(debug_state, renderer_state, block, height - 5, f64(target_fps), colors[block_index % len(GRAPH_COLORS)]);
            }
        }

        {
            values := make([][]f64, SNAPSHOTS_COUNT, context.temp_allocator);
            for snapshot_index in 0 ..< SNAPSHOTS_COUNT {
                snapshot_values := make([]f64, len(debug_state.timed_block_data), context.temp_allocator);
                for block, block_index in debug_state.timed_block_data {
                    if block == nil || block.name == "total" {
                        snapshot_values[block_index] = 0.0;
                        continue;
                    }
                    value := block.snapshots[snapshot_index];
                    snapshot_values[block_index] = f64(value.duration);
                }

                values[snapshot_index] = snapshot_values;
            }

            height : i32 = 200;
            width : i32 = SNAPSHOTS_COUNT * 6;
            renderer.ui_stacked_graph(renderer_state, values, width, height, f64(target_fps), debug_state.snapshot_index, GRAPH_COLORS);
        }
    }
}

draw_timed_block_graph :: proc(debug_state: ^Debug_State, renderer_state: ^renderer.Renderer_State, block: ^Timed_Block, height: i32, max_value: f64, color: renderer.Color) {
    values := make([]f64, SNAPSHOTS_COUNT, context.temp_allocator);
    stat_hit_count: Statistic;
    stat_duration: Statistic;
    statistic_begin(&stat_hit_count);
    statistic_begin(&stat_duration);
    for snapshot, index in block.snapshots {
        statistic_accumulate(&stat_hit_count, f64(snapshot.hit_count));
        statistic_accumulate(&stat_duration, f64(snapshot.duration));
        values[index] = f64(snapshot.duration);
    }
    statistic_end(&stat_hit_count);
    statistic_end(&stat_duration);

    renderer.ui_graph(renderer_state, values, SNAPSHOTS_COUNT, height, max_value, debug_state.snapshot_index, color);
}
