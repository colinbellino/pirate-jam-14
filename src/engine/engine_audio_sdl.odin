package engine

import "core:c"
import "core:log"
import "core:mem"
import "core:fmt"
import "core:runtime"

import "vendor:sdl2"
import mixer "vendor:sdl2/mixer"

CHUNK_SIZE :: 1024

Audio_State :: struct {
    device_id:  sdl2.AudioDeviceID,

    wav_spec:   sdl2.AudioSpec,
    wav_buffer: [^]u8,
    wav_len:    u32,

    chunk:      ^mixer.Chunk,
}

audio_init :: proc () -> (ok: bool) {
    context.allocator = _e.allocator
    profiler_zone("audio_init", PROFILER_COLOR_ENGINE)

    log.infof("Audio (SDL) ------------------------------------------------")
    defer {
        if ok {
            log.infof("  Init:                 OK")
        } else {
            log.warnf("  Init:                 KO")
        }
    }

    _e.audio = new(Audio_State)

    if sdl2.InitSubSystem({ .AUDIO }) != 0 {
        log.errorf("Couldn't init audio subsystem: %v", sdl2.GetError())
        return
    }

    if mixer.Init({ }) != 0 {
        log.errorf("Couldn't init audio mixer: %v", mixer.GetError())
        return
    }

    if mixer.OpenAudio(48000, mixer.DEFAULT_FORMAT, mixer.DEFAULT_CHANNELS, CHUNK_SIZE) != 0 {
        log.errorf("Couldn't open audio: %v", mixer.GetError())
        return
    }

    allocated_channels := mixer.AllocateChannels(8)
    if allocated_channels == 0 {
        log.errorf("Couldn't allocate channels.")
        return
    }

    _e.audio.chunk = mixer.LoadWAV("../media/audio/sounds/LETSGO.WAV")

    if mixer.PlayChannel(-1, _e.audio.chunk, 0) != 0 {
        log.errorf("Couldn't play sound: %v", mixer.GetError())
    }

    // if sdl2.LoadWAV("../media/audio/sounds/LETSGO.WAV", &_e.audio.wav_spec, &_e.audio.wav_buffer, &_e.audio.wav_len) == nil {
    //     log.errorf("Couldn't load audio file: %v", sdl2.GetError())
    //     return
    // }

    // desired_spec := sdl2.AudioSpec {
    //     freq = 48000,
    //     format = sdl2.AUDIO_F32,
    //     channels = 2,
    //     samples = 4096,
    // }
    // _e.audio.device_id = sdl2.OpenAudioDevice(nil, false, &desired_spec, nil, false)
    // if _e.audio.device_id == 0 {
    //     log.errorf("Couldn't open audio device: %v", sdl2.GetError())
    //     return
    // }

    // queue_error := sdl2.QueueAudio(_e.audio.device_id, _e.audio.wav_buffer, _e.audio.wav_len)
    // if queue_error != 0 {
    //     log.warnf("Couldn't queue audio: %v", queue_error)
    // }
    // sdl2.FreeWAV(_e.audio.wav_buffer)

    // sdl2.PauseAudioDevice(_e.audio.device_id, false)

    // sdl2.Delay(5000)

    ok = true
    return
}

audio_quit :: proc() {
    // sdl2.CloseAudioDevice(_e.audio.device_id)
    // mixer.Quit()
}
