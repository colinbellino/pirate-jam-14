package engine

import "core:c"
import "core:log"
import "core:runtime"

import slog "../sokol-odin/sokol/log"
import saudio "../sokol-odin/sokol/audio"

Audio_State :: struct {
    initialized:    bool,
    num_frames:     c.int,
    num_channels:   c.int,
}

engine_audio_init :: proc () {
    context.allocator = _e.allocator
    profiler_zone("engine_audio_init", PROFILER_COLOR_ENGINE)
    _e.audio = new(Audio_State)

    log.infof("Audio (sokol) ----------------------------------------------")

    saudio.setup({
        logger = { func = slog.func },
        stream_cb = auto_cast(_stream_callback),
    })
    if saudio.isvalid() == false {
        log.warnf("  Couldn't initialize audio.")
    }
    _e.audio.num_frames = saudio.sample_rate()
    _e.audio.num_channels = saudio.channels()
    _e.audio.initialized = true
    log.infof("  num_frames:           %v", _e.audio.num_frames)
    log.infof("  num_channels:         %v", _e.audio.num_channels)
    if _e.audio.initialized {
        log.infof("  initialized:          OK")
    } else {
        log.errorf("  initialized:          KO")
    }
}

engine_audio_quit :: proc() {
    saudio.shutdown()
}

_stream_callback :: proc "c" (buffer: [^]f32, _num_frames: c.int, _num_channels: c.int) {
    if _e.audio.initialized == false {
        return
    }

    context = _e.ctx

    num_frames := saudio.sample_rate()
    num_channels := saudio.channels()
    log.debugf("num_frames:          %v | num_channels: %v", num_frames, num_channels)
    log.debugf("_num_frames:         %v | _num_channels: %v", _num_frames, _num_channels)
    log.debugf("_e.audio.num_frames: %v | _num_channels: %v", _e.audio.num_frames, _e.audio.num_channels)

    assert(1 == num_channels)
    @(static) count : u32 = 0
    for i := 0; i < int(_num_frames); i += 1 {
        buffer[i] = (count & (1<<3) == 0) ? 0.5 : -0.5
        count += 1
    }
}

audio_debug_bleep :: proc() {
    // num_frames := saudio.expect()
    // for i in 0..<num_frames {
    //     state.even_odd += 1
    //     state.samples[state.sample_pos] = (state.even_odd & (1<<5)) == 0 ? 0.05 : -0.05
    //     state.sample_pos += 1
    //     if state.sample_pos == NUM_SAMPLES {
    //         state.sample_pos = 0
    //         saudio.push(&state.samples[0], NUM_SAMPLES)
    //     }
    // }
}
