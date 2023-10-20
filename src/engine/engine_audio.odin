package engine

import slog "../sokol-odin/sokol/log"
import saudio "../sokol-odin/sokol/audio"

NUM_SAMPLES :: 32

state: struct {
    even_odd: u32,
    sample_pos: int,
    samples: [NUM_SAMPLES]f32,
}

engine_audio_init :: proc () {
    saudio.setup({
        logger = { func = slog.func },
    })
}

audio_debug_bleep :: proc() {
    num_frames := saudio.expect()
    for i in 0..<num_frames {
        state.even_odd += 1
        state.samples[state.sample_pos] = (state.even_odd & (1<<5)) == 0 ? 0.05 : -0.05
        state.sample_pos += 1
        if state.sample_pos == NUM_SAMPLES {
            state.sample_pos = 0
            saudio.push(&state.samples[0], NUM_SAMPLES)
        }
    }
}
