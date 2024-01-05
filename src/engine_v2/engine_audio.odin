package engine_v2

import "core:c"
import "core:log"
import "core:mem"
import "core:fmt"
import "core:runtime"
import "core:math"
import "core:strings"
import "core:path/filepath"
import "vendor:sdl2"
import mixer "../sdl2_mixer"
import "../tools"

Chunk     :: mixer.Chunk
Music     :: mixer.Music

Audio_State :: struct {
    arena:              tools.Named_Virtual_Arena,
    allocated_channels: c.int,
    playing_channels:   [CHANNELS_COUNT]^Audio_Clip,
    clips:              map[Asset_Id]Audio_Clip,
    volume_main:        f32,
    volume_music:       f32,
    volume_sound:       f32,
}

Audio_Clip_Types :: enum { Sound, Music }

Audio_Clip :: struct {
    type:       Audio_Clip_Types,
    data:      ^Audio_Clip_Data,
}

Audio_Clip_Data :: union { Chunk, Music }

CHUNK_SIZE       :: 1024
CHANNELS_COUNT   :: 8
AUDIO_ARENA_SIZE :: mem.Megabyte

@(private="file")
_audio: ^Audio_State

audio_init :: proc() -> (audio_state: ^Audio_State, ok: bool) #optional_ok {
    profiler_zone("audio_init", PROFILER_COLOR_ENGINE)

    log.infof("Audio (SDL) ------------------------------------------------")
    defer log_ok(ok)

    alloc_err: mem.Allocator_Error
    _audio, alloc_err = tools.mem_named_arena_virtual_bootstrap_new_by_name(Audio_State, "arena", AUDIO_ARENA_SIZE, "audio")
    if alloc_err != .None {
        log.errorf("Couldn't allocate arena: %v", alloc_err)
        return
    }
    context.allocator = _audio.arena.allocator

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

    log.infof("  version:              %v.%v.%v", mixer.MAJOR_VERSION, mixer.MINOR_VERSION, mixer.PATCHLEVEL)
    linked_version := mixer.Linked_Version()
    log.infof("  linked_version:       %v.%v.%v", linked_version.major, linked_version.minor, linked_version.patch)
    if mixer.MAJOR_VERSION != linked_version.major || mixer.MINOR_VERSION != linked_version.minor || mixer.PATCHLEVEL != linked_version.patch {
        log.errorf("Linked version didn't match: %v.%v.%v -> %v.%v.%v", mixer.MAJOR_VERSION, mixer.MINOR_VERSION, mixer.PATCHLEVEL, linked_version.major, linked_version.minor, linked_version.patch)
        return
    }

    _audio.allocated_channels = mixer.AllocateChannels(CHANNELS_COUNT)
    if _audio.allocated_channels == 0 {
        log.errorf("Couldn't allocate %v channels.", CHANNELS_COUNT)
        return
    }
    log.infof("  allocated_channels:   %v", _audio.allocated_channels)

    mixer.ChannelFinished(_channel_finished)

    audio_set_volume_main(_audio.volume_main)

    audio_state = _audio
    ok = true
    return
}

audio_reload :: proc(audio_state: ^Audio_State) {
    assert(audio_state != nil)
    _audio = audio_state
}

audio_quit :: proc() {
    // mixer.Quit()
}

// TODO: handle load options for music/sfx
audio_load_clip :: proc(filepath: string, asset_id: Asset_Id, type: Audio_Clip_Types) -> (clip: ^Audio_Clip, ok: bool) {
    context.allocator = _audio.arena.allocator

    if asset_id in _audio.clips {
        return &_audio.clips[asset_id]
    }

    _audio.clips[asset_id] = Audio_Clip {}
    clip = &_audio.clips[asset_id]
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
    _audio.playing_channels[channel_used] = clip
    return true
}
audio_play_sound_asset :: proc(asset_id: Asset_Id) -> (ok: bool) {
    asset := asset_get_by_asset_id(asset_id)
    if asset.state != .Loaded { return }
    asset_info := asset.info.(Asset_Info_Audio) or_return
    return audio_play_sound(asset_info)
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
    return mixer.Playing(channel), _audio.playing_channels[channel]
}

audio_set_volume_main :: proc(volume: f32) {
    _audio.volume_main = volume
    audio_set_volume_music(_audio.volume_music)
    audio_set_volume_sound(_audio.volume_sound)
}
audio_set_volume_music :: proc(volume: f32) {
    _audio.volume_music = volume
    mixer.VolumeMusic(c.int(volume * _audio.volume_main * mixer.MAX_VOLUME))
}
audio_set_volume_sound :: proc(volume: f32) {
    _audio.volume_sound = volume
    for channel := 0; channel < CHANNELS_COUNT; channel += 1 {
        mixer.Volume(c.int(channel), c.int(volume * _audio.volume_main * mixer.MAX_VOLUME))
    }
}

audio_is_enabled :: proc() -> bool { return _audio != nil }

_channel_finished :: proc "c" (channel: c.int) {
    _audio.playing_channels[channel] = nil
}

ui_widget_audio :: proc() {
    if ui_collapsing_header("Audio") {
        if audio_is_enabled() {
            volume_main := _audio.volume_main
            if ui_slider_float("volume_main", &volume_main, 0, 1) {
                audio_set_volume_main(volume_main)
            }
            volume_music := _audio.volume_music
            if ui_slider_float("volume_music", &volume_music, 0, 1) {
                audio_set_volume_music(volume_music)
            }
            volume_sound := _audio.volume_sound
            if ui_slider_float("volume_sound", &volume_sound, 0, 1) {
                audio_set_volume_sound(volume_sound)
            }

            ui_text("allocated_channels: %v", _audio.allocated_channels)
            {
                columns := []string { "index", "infos", "actions" }
                if ui_table(columns) {
                    for channel_index := 0; channel_index < int(_audio.allocated_channels); channel_index += 1 {
                        ui_table_next_row()

                        for column, i in columns {
                            ui_table_set_column_index(i32(i))
                            playing, clip := audio_channel_playing(i32(channel_index))
                            switch column {
                                case "index": ui_text(fmt.tprintf("%v", channel_index))
                                case "infos": {
                                    ui_text("playing: %v (%v)", playing, clip)
                                }
                                case "actions": {
                                    if ui_button_disabled("Stop", playing == 0) {
                                        audio_stop_sound(i32(channel_index))
                                    }
                                }
                                case: ui_text("x")
                            }
                        }
                    }
                }
            }

            if ui_button("Stop music") {
                audio_stop_music()
            }

            {
                columns := []string { "asset_id", "file_name", "infos" }
                if ui_table(columns) {
                    for asset_id, clip in _audio.clips {
                        ui_table_next_row()

                        asset := asset_get_by_asset_id(asset_id)
                        asset_info := asset.info.(Asset_Info_Audio)
                        for column, i in columns {
                            ui_table_set_column_index(i32(i))
                            switch column {
                                case "asset_id": ui_text(fmt.tprintf("%v", asset_id))
                                case "file_name": ui_text(asset.file_name)
                                case "infos": {
                                    ui_push_id(i32(asset_id))
                                    if ui_button("Play") {
                                        switch asset_info.type {
                                            case .Sound: { audio_play_sound(asset_info) }
                                            case .Music: { audio_play_music(asset_info) }
                                        }
                                    }
                                    ui_pop_id()
                                }
                                case: ui_text("x")
                            }
                        }
                    }
                }
            }
        } else {
            ui_text("Audio module not enabled.")
        }
    }
}
