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

Chunk     :: mixer.Chunk

Audio_State :: struct {
    enabled:        bool,
    clips:          map[Asset_Id]Audio_Clip,
}

Audio_Clip :: struct {
    chunk:   ^Chunk,
}

audio_init :: proc () -> (ok: bool) {
    context.allocator = _e.allocator
    profiler_zone("audio_init", PROFILER_COLOR_ENGINE)

    log.infof("Audio (SDL) ------------------------------------------------")
    defer {
        _e.audio.enabled = ok
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

    // audio_load_sound("../media/audio/sounds/LETSGO.WAV", &_e.audio.clip_letsgo)
    // audio_load_sound("../media/audio/sounds/confirm.mp3", &_e.audio.clip_confirm)

    ok = true
    return
}

audio_quit :: proc() {
    // mixer.Quit()
}

// TODO: handle load options for music/sfx
audio_load_clip :: proc(filepath: string, asset_id: Asset_Id) -> (clip: ^Audio_Clip, ok: bool) {
    if asset_id in _e.audio.clips {
        return &_e.audio.clips[asset_id]
    }

    _e.audio.clips[asset_id] = Audio_Clip {}
    clip = &_e.audio.clips[asset_id]
    clip.chunk = mixer.LoadWAV(strings.clone_to_cstring(filepath, context.temp_allocator))
    if clip.chunk == nil {
        log.warnf("Couldn't load clip (%v): %v", filepath, mixer.GetError())
        return
    }

    ok = true
    return
}

audio_unload_clip :: proc(asset_id: Asset_Id) {
    // TODO:
}

audio_play_sound :: proc(clip: ^Audio_Clip) -> (ok: bool) {
    channel_used := mixer.PlayChannel(-1, clip.chunk, 0)
    if channel_used == -1 {
        log.errorf("Couldn't play sound: %v", mixer.GetError())
        return
    }
    return true
}

audio_is_enabled :: proc() -> bool { return _e.audio.enabled }
