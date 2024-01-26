package game

import "core:time"
import "core:math"
import "core:log"
import "../engine"

@(deferred_out=_game_ui_window_end)
game_ui_window :: proc(name: string, open : ^bool = nil, flags: engine.WindowFlag = .NoDocking | .NoResize | .NoMove | .NoCollapse) -> bool {
    when engine.IMGUI_ENABLE {
        ui_push_theme_game()
        return engine.ui_begin(name, open, flags)
    } else {
        return false
    }
}

@(private="file")
_game_ui_window_end :: proc(collapsed: bool) {
    when engine.IMGUI_ENABLE {
        engine._ui_end()
        ui_pop_theme_game()
    }
}

game_ui_button :: proc(label: string, disabled: bool = false) -> bool {
    clicked := engine.ui_button_disabled(label, disabled)
    if disabled {
        return false
    }
    if clicked {
        engine.audio_play_sound(_mem.game.asset_sound_confirm)
    }
    return clicked
}

game_ui_text :: proc(v: string, args: ..any) {
    engine.ui_text(v, ..args)
}

UI_Rect :: struct {
    pos:      Vector2f32,
    scale:    Vector2f32,
    t_pos:    Vector2i32,
    t_size:   Vector2i32,
    asset:    Asset_Id,
}
push_ui_rect :: proc(rect: UI_Rect) {
    _mem.game.ui_rects[_mem.game.ui_rects_count] = rect
    _mem.game.ui_rects_count += 1
}
game_ui_hud :: proc() {
    window_size := engine.get_window_size()
    camera := _mem.game.world_camera

    player_cleaner, player_cleaner_err := engine.entity_get_component_err(_mem.game.play.player, Component_Cleaner)
    if player_cleaner_err == .None {
        progress := player_cleaner.water_level / f32(WATER_LEVEL_MAX)
        push_ui_rect(UI_Rect {
            pos = { 0.25, 0.25 },
            scale = { 2, 1 },
            t_pos = { 0*16, 2*16 },
            t_size = { 2*16, 1*16 },
            asset = _mem.game.asset_image_spritesheet,
        })
        push_ui_rect(UI_Rect {
            pos = { 0.25, 0.25 },
            scale = { 2*progress, 1 },
            t_pos = { 0*16, 3*16 },
            t_size = { 2*16, 1*16 },
            asset = _mem.game.asset_image_spritesheet,
        })
        push_ui_rect(UI_Rect {
            pos = { 0.25, 0.25 },
            scale = { 3, 1 },
            t_pos = { 0*16, 4*16 },
            t_size = { 3*16, 1*16 },
            asset = _mem.game.asset_image_spritesheet,
        })
    }
    {
        progress := f32(_mem.game.play.time_remaining) / f32(LEVEL_DURATION)
        x := (window_size.x / 16 / camera.zoom) * 1.75
        push_ui_rect(UI_Rect {
            pos = { x + 0.25, 0.25 },
            scale = { 2, 1 },
            t_pos = { 3*16, 2*16 },
            t_size = { 2*16, 1*16 },
            asset = _mem.game.asset_image_spritesheet,
        })
        push_ui_rect(UI_Rect {
            pos = { x + 0.25, 0.25 },
            scale = { 2*progress, 1 },
            t_pos = { 3*16, 3*16 },
            t_size = { 2*16, 1*16 },
            asset = _mem.game.asset_image_spritesheet,
        })
        push_ui_rect(UI_Rect {
            pos = { x + 0.25, 0.25 },
            scale = { 3, 1 },
            t_pos = { 3*16, 4*16 },
            t_size = { 3*16, 1*16 },
            asset = _mem.game.asset_image_spritesheet,
        })
    }
    push_ui_score({ (window_size.x / 16 / camera.zoom) * 0.7, 0.25 })
}

game_ui_game_over :: proc() {
    window_size := engine.get_window_size()
    camera := _mem.game.world_camera
    push_ui_score({ (window_size.x / 16 / camera.zoom) * 0.7, (window_size.y / 16 / camera.zoom) * 0.6 })

    push_ui_rect(UI_Rect {
        pos = { (window_size.x / 16 / camera.zoom) * 0.6, (window_size.y / 16 / camera.zoom) * 0.9 },
        scale = { 8, 2 },
        t_pos = { 8*16, 2*16 },
        t_size = { 8*16, 2*16 },
        asset = _mem.game.asset_image_spritesheet,
    })
}

push_ui_score :: proc(pos: Vector2f32) {
    x := pos.x
    push_ui_rect(UI_Rect {
        pos = { x, pos.y },
        scale = { 3, 1 },
        t_pos = { 5*16, 0*16 },
        t_size = { 3*16, 1*16 },
        asset = _mem.game.asset_image_spritesheet,
    })
    {
        s := f32(0.7)
        score_0     := (_mem.game.score / 1)     % 10;
        score_1     := (_mem.game.score / 10)    % 10;
        score_2     := (_mem.game.score / 100)   % 10;
        score_3     := (_mem.game.score / 1000)  % 10;
        score_4     := (_mem.game.score / 10000) % 10;
        // push_ui_number({ x + 2.25 + 1*s, 0.25 }, int(score_4))
        push_ui_number({ x + 1.5 + 2*s, pos.y }, int(score_3))
        push_ui_number({ x + 1.5 + 3*s, pos.y }, int(score_2))
        push_ui_number({ x + 1.5 + 4*s, pos.y }, int(score_1))
        push_ui_number({ x + 1.5 + 5*s, pos.y }, int(score_0))
    }
}

push_ui_number :: proc(pos: Vector2f32, number: int) {
    texture_offset := engine.grid_index_to_position(number, { 5, 2 })
    x := 3 + texture_offset.x
    y := 6 + texture_offset.y
    push_ui_rect(UI_Rect {
        pos = pos,
        scale = { 1, 1 },
        t_pos = { x*16, y*16 },
        t_size = { 1*16, 1*16 },
        asset = _mem.game.asset_image_spritesheet,
    })
}

game_ui_title :: proc() {
    push_ui_rect(UI_Rect {
        pos = { 0, 0 },
        scale = { 20 * 2, 11.25 * 2 },
        t_pos = { 0, 0 },
        t_size = { 320, 180 },
        asset = _mem.game.asset_image_title,
    })
}

ui_push_theme_game :: proc() {
    engine.ui_push_style_var_vec2(.WindowPadding, { 15, 15 })
    engine.ui_push_style_var_float(.WindowRounding, 5.0)
    engine.ui_push_style_var_vec2(.FramePadding, { 5, 5 })
    engine.ui_push_style_var_float(.FrameRounding, 4.0)
    engine.ui_push_style_var_vec2(.ItemSpacing, { 12, 8 })
    engine.ui_push_style_var_vec2(.ItemInnerSpacing, { 8, 6 })
    engine.ui_push_style_var_float(.IndentSpacing, 25.0)
    engine.ui_push_style_var_float(.ScrollbarSize, 15.0)
    engine.ui_push_style_var_float(.ScrollbarRounding, 9.0)
    engine.ui_push_style_var_float(.GrabMinSize, 5.0)
    engine.ui_push_style_var_float(.GrabRounding, 3.0)

    engine.ui_push_style_color(.Text, engine.Vec4 { 0.25, 0.24, 0.23, 1.00 })
    engine.ui_push_style_color(.TextDisabled, engine.Vec4 { 0.40, 0.39, 0.38, 0.77 })
    engine.ui_push_style_color(.WindowBg, engine.Vec4 { 0.92, 0.91, 0.88, 1.0 })
    engine.ui_push_style_color(.ChildBg, engine.Vec4 { 1.00, 0.98, 0.95, 0.78 })
    engine.ui_push_style_color(.PopupBg, engine.Vec4 { 0.92, 0.91, 0.88, 0.92 })
    engine.ui_push_style_color(.Border, engine.Vec4 { 0.84, 0.83, 0.80, 0.65 })
    engine.ui_push_style_color(.BorderShadow, engine.Vec4 { 0.92, 0.91, 0.88, 0.00 })
    engine.ui_push_style_color(.FrameBg, engine.Vec4 { 1.00, 0.98, 0.95, 1.00 })
    engine.ui_push_style_color(.FrameBgHovered, engine.Vec4 { 0.99, 1.00, 0.40, 0.78 })
    engine.ui_push_style_color(.FrameBgActive, engine.Vec4 { 0.26, 1.00, 0.00, 1.00 })
    engine.ui_push_style_color(.TitleBg, engine.Vec4 { 1.00, 0.98, 0.95, 1.00 })
    engine.ui_push_style_color(.TitleBgActive, engine.Vec4 { 0.75, 0.75, 0.75, 1.00 })
    engine.ui_push_style_color(.TitleBgCollapsed, engine.Vec4 { 1.00, 0.98, 0.95, 0.75 })
    engine.ui_push_style_color(.MenuBarBg, engine.Vec4 { 1.00, 0.98, 0.95, 0.47 })
    engine.ui_push_style_color(.ScrollbarBg, engine.Vec4 { 1.00, 0.98, 0.95, 1.00 })
    engine.ui_push_style_color(.ScrollbarGrab, engine.Vec4 { 0.00, 0.00, 0.00, 0.21 })
    engine.ui_push_style_color(.ScrollbarGrabHovered, engine.Vec4 { 0.90, 0.91, 0.00, 0.78 })
    engine.ui_push_style_color(.ScrollbarGrabActive, engine.Vec4 { 0.25, 1.00, 0.00, 1.00 })
    engine.ui_push_style_color(.CheckMark, engine.Vec4 { 0.25, 1.00, 0.00, 0.80 })
    engine.ui_push_style_color(.SliderGrab, engine.Vec4 { 0.00, 0.00, 0.00, 0.14 })
    engine.ui_push_style_color(.SliderGrabActive, engine.Vec4 { 0.25, 1.00, 0.00, 1.00 })
    engine.ui_push_style_color(.Button, engine.Vec4 { 0.00, 0.00, 0.00, 0.14 })
    engine.ui_push_style_color(.ButtonHovered, engine.Vec4 { 0.99, 1.00, 0.22, 0.86 })
    engine.ui_push_style_color(.ButtonActive, engine.Vec4 { 0.89, 0.90, 0.12, 1.00 })
    engine.ui_push_style_color(.Header, engine.Vec4 { 0.25, 1.00, 0.00, 0.76 })
    engine.ui_push_style_color(.HeaderHovered, engine.Vec4 { 0.25, 1.00, 0.00, 0.86 })
    engine.ui_push_style_color(.HeaderActive, engine.Vec4 { 0.25, 1.00, 0.00, 1.00 })
    engine.ui_push_style_color(.Separator, { 1, 0, 0, 1 })
    engine.ui_push_style_color(.SeparatorHovered, { 1, 0, 0, 1 })
    engine.ui_push_style_color(.SeparatorActive, { 1, 0, 0, 1 })
    engine.ui_push_style_color(.ResizeGrip, engine.Vec4 { 0.00, 0.00, 0.00, 0.04 })
    engine.ui_push_style_color(.ResizeGripHovered, engine.Vec4 { 0.25, 1.00, 0.00, 0.78 })
    engine.ui_push_style_color(.ResizeGripActive, engine.Vec4 { 0.25, 1.00, 0.00, 1.00 })
    engine.ui_push_style_color(.Tab, { 0, 1, 0, 1 })
	engine.ui_push_style_color(.TabHovered, { 0, 1, 0, 1 })
	engine.ui_push_style_color(.TabActive, { 0, 1, 0, 1 })
	engine.ui_push_style_color(.TabUnfocused, { 0, 1, 0, 1 })
	engine.ui_push_style_color(.TabUnfocusedActive, { 0, 1, 0, 1 })
	engine.ui_push_style_color(.DockingPreview, { 0, 1, 0, 1 })
	engine.ui_push_style_color(.DockingEmptyBg, { 0, 1, 0, 1 })
    engine.ui_push_style_color(.PlotLines, engine.Vec4 { 0.40, 0.39, 0.38, 0.63 })
    engine.ui_push_style_color(.PlotLinesHovered, engine.Vec4 { 0.25, 1.00, 0.00, 1.00 })
    engine.ui_push_style_color(.PlotHistogram, engine.Vec4 { 0.40, 0.39, 0.38, 0.63 })
    engine.ui_push_style_color(.PlotHistogramHovered, engine.Vec4 { 0.25, 1.00, 0.00, 1.00 })
    engine.ui_push_style_color(.TableHeaderBg, { 0, 0, 1, 1 })
    engine.ui_push_style_color(.TableBorderStrong, { 0, 0, 1, 1 })
    engine.ui_push_style_color(.TableBorderLight, { 0, 0, 1, 1 })
    engine.ui_push_style_color(.TableRowBg, { 0, 0, 1, 1 })
    engine.ui_push_style_color(.TableRowBgAlt, { 0, 0, 1, 1 })
    engine.ui_push_style_color(.TextSelectedBg, engine.Vec4 { 0.25, 1.00, 0.00, 0.43 })
    engine.ui_push_style_color(.DragDropTarget, { 0, 0, 1, 1 })
    engine.ui_push_style_color(.NavHighlight, { 0, 0, 1, 1 })
    engine.ui_push_style_color(.NavWindowingHighlight, { 0, 0, 1, 1 })
    engine.ui_push_style_color(.NavWindowingDimBg, { 0, 0, 1, 1 })
}

ui_pop_theme_game :: proc() {
    engine.ui_pop_style_var(11)
    engine.ui_pop_style_color(54)
}

ui_push_theme_debug :: proc() {
    THEME_BG            :: engine.Vec4 { 0.1568627450980392, 0.16470588235294117, 0.21176470588235294, 1 }
    THEME_BG_FADED      :: engine.Vec4 { 0.26666666666666666, 0.2784313725490196, 0.35294117647058826, 1 }
    THEME_BG_FOCUSED    :: engine.Vec4 { 0.36, 0.37, 0.45, 1 }
    THEME_FOREGROUND    :: engine.Vec4 { 0.5725490196078431, 0.3764705882352941, 0.6705882352941176, 1 }
    THEME_HIGH_ACCENT   :: engine.Vec4 { 1, 0.4745098039215686, 0.7764705882352941, 1 }
    THEME_ACCENT        :: engine.Vec4 { 0.7411764705882353, 0.5764705882352941, 0.9764705882352941, 1 }
    THEME_FADED         :: engine.Vec4 { 0.3843137254901961, 0.4470588235294118, 0.6431372549019608, 1 }
    THEME_RED           :: engine.Vec4 { 1, 0.3333333333333333, 0.27058823529411763, 1 }
    THEME_GREEN         :: engine.Vec4 { 0.25882352941176473, 1, 0.13333333333333333, 1 }
    THEME_WARNING       :: engine.Vec4 { 0.9215686274509803, 0.5568627450980392, 0.25882352941176473, 1 }
    THEME_WHITE         :: engine.Vec4 { 0.9725490196078431, 0.9725490196078431, 0.9490196078431372, 1 }
    THEME_GENERIC_ASSET :: engine.Vec4 { 1, 0.4, 0.6, 1 }
    THEME_YELLOW        :: engine.Vec4 { 0.9450980392156862, 0.9803921568627451, 0.5490196078431373, 1 }

    engine.ui_push_style_var_float(.FrameRounding, 3)
    engine.ui_push_style_var_float(.PopupRounding, 3)
    engine.ui_push_style_var_float(.WindowRounding, 6)

    engine.ui_push_style_color(.Text, THEME_WHITE)
    engine.ui_push_style_color(.PopupBg, THEME_BG)
    engine.ui_push_style_color(.WindowBg, THEME_BG)
    engine.ui_push_style_color(.TitleBg, THEME_BG_FADED)
    engine.ui_push_style_color(.TitleBgActive, THEME_FADED)

    engine.ui_push_style_color(.TextSelectedBg, THEME_ACCENT)
    engine.ui_push_style_color(.ChildBg, THEME_BG)

    engine.ui_push_style_color(.PopupBg, THEME_BG)

    engine.ui_push_style_color(.Header, THEME_FADED)
    engine.ui_push_style_color(.HeaderActive, THEME_ACCENT)
    engine.ui_push_style_color(.HeaderHovered, THEME_ACCENT)

    engine.ui_push_style_color(.TabActive, THEME_ACCENT)
    engine.ui_push_style_color(.TabHovered, THEME_HIGH_ACCENT)
    engine.ui_push_style_color(.TabUnfocused, THEME_BG_FADED)
    engine.ui_push_style_color(.TabUnfocusedActive, THEME_HIGH_ACCENT)
    engine.ui_push_style_color(.Tab, THEME_BG_FADED)
    engine.ui_push_style_color(.DockingEmptyBg, THEME_BG_FADED)
    engine.ui_push_style_color(.DockingPreview, THEME_FADED)

    engine.ui_push_style_color(.Button, THEME_FOREGROUND)
    engine.ui_push_style_color(.ButtonActive, THEME_HIGH_ACCENT)
    engine.ui_push_style_color(.ButtonHovered, THEME_ACCENT)

    engine.ui_push_style_color(.FrameBg, THEME_BG_FADED)
    engine.ui_push_style_color(.FrameBgActive, THEME_BG_FOCUSED)
    engine.ui_push_style_color(.FrameBgHovered, THEME_BG_FOCUSED)

    engine.ui_push_style_color(.SeparatorActive, THEME_ACCENT)
    engine.ui_push_style_color(.ButtonActive, THEME_HIGH_ACCENT)
}

ui_pop_theme_debug :: proc() {
    engine.ui_pop_style_var(3)
    engine.ui_pop_style_color(26)
}

get_window_center :: proc(window_size: engine.Vec2) -> engine.Vec2 {
    engine_window_size := engine.get_window_size()
    return {
        f32(engine_window_size.x) / 2 - window_size.x / 2,
        f32(engine_window_size.y) / 2 - window_size.y / 2,
    }
}

game_ui_window_center :: proc(size: engine.Vec2) {
    engine.ui_set_window_size_vec2(size, .Always)
    engine.ui_set_window_pos_vec2(get_window_center(size), .Always)
}
