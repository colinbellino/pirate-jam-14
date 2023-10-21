package engine

import "core:c"
import "core:log"
import "core:mem"
import "core:fmt"
import "core:runtime"
import "core:strings"

import "vendor:sdl2"
import mixer "vendor:sdl2/mixer"

CHUNK_SIZE :: 1024

Chunk :: mixer.Chunk

Audio_Clip :: struct {
    chunk:   ^Chunk,
}

Audio_State :: struct {
    device_id:      sdl2.AudioDeviceID,

    clip_letsgo:    Audio_Clip,
    clip_confirm:   Audio_Clip,
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

    mixer_flags := mixer.InitFlags { .MP3 }
    if mixer.Init(mixer_flags) != transmute(c.int) mixer_flags {
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

    audio_load_sound("../media/audio/sounds/LETSGO.WAV", &_e.audio.clip_letsgo)
    audio_load_sound("../media/audio/sounds/confirm.mp3", &_e.audio.clip_confirm)

    ok = true
    return
}

audio_quit :: proc() {
    // mixer.Quit()
}

audio_load_sound :: proc(filepath: string, clip: ^Audio_Clip) -> (ok: bool) {
    clip.chunk = mixer.LoadWAV(strings.clone_to_cstring(filepath, context.temp_allocator))
    ok = clip.chunk != nil
    if ok == false {
        log.warnf("Couldn't load clip (%v): %v", filepath, mixer.GetError())
    }
    return
}

audio_play_sound :: proc(clip: ^Audio_Clip) -> (ok: bool) {
    if mixer.PlayChannel(-1, clip.chunk, 0) != 0 {
        log.errorf("Couldn't play sound: %v", mixer.GetError())
        return
    }
    return true
}
