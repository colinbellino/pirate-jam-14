package engine

import "core:c"
import "core:log"
import "core:mem"
import "core:fmt"
import "core:runtime"
import "core:strings"
import "core:path/filepath"

import "vendor:sdl2"
import mixer "vendor:sdl2/mixer"

CHUNK_SIZE     :: 1024
CHANNELS_COUNT :: 8

Chunk     :: mixer.Chunk
Music     :: mixer.Music

Audio_State :: struct {
    enabled:            bool,
    allocated_channels: c.int,
    playing_channels:   [CHANNELS_COUNT]^Audio_Clip,
    clips:              map[Asset_Id]Audio_Clip,
}

Audio_Clip_Types :: enum { Sound, Music }

Audio_Clip :: struct {
    type:       Audio_Clip_Types,
    data:      ^Audio_Clip_Data,
}

Audio_Clip_Data :: union { Chunk, Music }

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

    mixer_flags := mixer.InitFlags { .MP3, .OGG }
    if mixer.Init(mixer_flags) != transmute(c.int) mixer_flags {
        log.errorf("Couldn't init audio mixer: %v", mixer.GetError())
        return
    }

    if mixer.OpenAudio(48000, mixer.DEFAULT_FORMAT, mixer.DEFAULT_CHANNELS, CHUNK_SIZE) != 0 {
        log.errorf("Couldn't open audio: %v", mixer.GetError())
        return
    }

    _e.audio.allocated_channels = mixer.AllocateChannels(CHANNELS_COUNT)
    if _e.audio.allocated_channels == 0 {
        log.errorf("Couldn't allocate %v channels.", CHANNELS_COUNT)
        return
    }
    log.infof("  allocated_channels:   %v", _e.audio.allocated_channels)

    mixer.ChannelFinished(_channel_finished)

    ok = true
    return
}

audio_quit :: proc() {
    // mixer.Quit()
}

// TODO: handle load options for music/sfx
audio_load_clip :: proc(filepath: string, asset_id: Asset_Id, type: Audio_Clip_Types) -> (clip: ^Audio_Clip, ok: bool) {
    if asset_id in _e.audio.clips {
        return &_e.audio.clips[asset_id]
    }

    _e.audio.clips[asset_id] = Audio_Clip {}
    clip = &_e.audio.clips[asset_id]
    clip.type = type

    switch clip.type {
        case .Sound: {
            clip.data = cast(^Audio_Clip_Data) mixer.LoadWAV(strings.clone_to_cstring(filepath, context.temp_allocator))
        }
        case .Music: {
            clip.data = cast(^Audio_Clip_Data) mixer.LoadMUS(strings.clone_to_cstring(filepath, context.temp_allocator))
        }
    }
    if clip.data == nil {
        log.warnf("Couldn't load clip (%v): %v", filepath, mixer.GetError())
        return
    }

    ok = true
    return
}

audio_unload_clip :: proc(asset_id: Asset_Id) {
    // TODO:
}

audio_play_sound :: proc { audio_play_sound_clip, audio_play_sound_asset }
audio_play_sound_clip :: proc(clip: ^Audio_Clip) -> (ok: bool) {
    assert(clip.type == .Sound, fmt.tprintf("Trying to play a sound but the clip type is %v", clip.type))

    channel_used := mixer.PlayChannel(-1, cast(^Chunk) clip.data, 0)
    if channel_used == -1 {
        log.errorf("Couldn't play sound: %v", mixer.GetError())
        return
    }
    _e.audio.playing_channels[channel_used] = clip
    return true
}
audio_play_sound_asset :: proc(asset_id: Asset_Id) -> (ok: bool) {
    asset := _e.assets.assets[asset_id]
    if asset.state != .Loaded { return }
    asset_info := asset.info.(Asset_Info_Audio) or_return
    return audio_play_sound(asset_info.clip)
}
audio_stop_sound :: proc(channel: c.int) -> (ok: bool) {
    error := mixer.HaltChannel(channel)
    if error != 0 {
        log.errorf("Couldn't stop sound: %v", mixer.GetError())
        return
    }

    return true
}

audio_play_music :: proc(clip: ^Audio_Clip, loops: c.int = 0) -> (ok: bool) {
    assert(clip.type == .Music, fmt.tprintf("Trying to play a music but the clip type is %v", clip.type))

    error := mixer.PlayMusic(cast(^Music) clip.data, loops)
    if error != 0 {
        log.errorf("Couldn't play music: %v", mixer.GetError())
        return
    }
    return true
}

audio_stop_music :: proc(duration_in_ms: c.int = 0) -> (ok: bool) {
    error := mixer.FadeOutMusic(duration_in_ms)
    if error != 0 {
        log.errorf("Couldn't stop music: %v", mixer.GetError())
        return
    }

    return true
}

audio_channel_playing :: proc(channel: c.int) -> (c.int, ^Audio_Clip) {
    return mixer.Playing(channel), _e.audio.playing_channels[channel]
}

audio_is_enabled :: proc() -> bool { return _e.audio.enabled }

_channel_finished :: proc "c" (channel: c.int) {
    _e.audio.playing_channels[channel] = nil
}
