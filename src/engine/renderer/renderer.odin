package renderer

import "core:fmt"
import "core:strings"
import "core:runtime"
import "core:time"
import "core:strconv"
import sdl "vendor:sdl2"
import mu "vendor:microui"

import logger "../logger"

State :: struct {
    renderer:       ^sdl.Renderer,
    ui_context:     mu.Context,
    atlas_texture:  ^sdl.Texture,
}

Color :: sdl.Color;

state := State {};

init :: proc(window: ^sdl.Window) {
    backend_idx: i32 = -1;
    n := sdl.GetNumRenderDrivers();

    if n <= 0 {
        fmt.eprintln("No render drivers available");
        return;
    }

    for i in 0..<n {
        info: sdl.RendererInfo;
        if err := sdl.GetRenderDriverInfo(i, &info); err == 0 {
            // NOTE(bill): "direct3d" seems to not work correctly
            if info.name == "opengl" {
                backend_idx = i;
                break;
            }
        }
    }

    state.renderer = sdl.CreateRenderer(window, backend_idx, {.ACCELERATED, .PRESENTVSYNC});
    if state.renderer == nil {
        fmt.eprintln("sdl.CreateRenderer:", sdl.GetError());
        return;
    }

    state.atlas_texture = sdl.CreateTexture(state.renderer, u32(sdl.PixelFormatEnum.RGBA32), .TARGET, mu.DEFAULT_ATLAS_WIDTH, mu.DEFAULT_ATLAS_HEIGHT);
    assert(state.atlas_texture != nil);
    if err := sdl.SetTextureBlendMode(state.atlas_texture, .BLEND); err != 0 {
        fmt.eprintln("sdl.SetTextureBlendMode:", err);
        return;
    }

    pixels := make([][4]u8, mu.DEFAULT_ATLAS_WIDTH*mu.DEFAULT_ATLAS_HEIGHT)
    defer delete(pixels);
    for alpha, i in mu.default_atlas_alpha {
        pixels[i].rgb = 0xff;
        pixels[i].a   = alpha;
    }

    if err := sdl.UpdateTexture(state.atlas_texture, nil, raw_data(pixels), 4*mu.DEFAULT_ATLAS_WIDTH); err != 0 {
        fmt.eprintln("sdl.UpdateTexture:", err);
        return;
    }

    ui_context := &state.ui_context;
    mu.init(ui_context);

    ui_context.text_width = mu.default_atlas_text_width;
    ui_context.text_height = mu.default_atlas_text_height;
}

quit :: proc() {
    sdl.DestroyRenderer(state.renderer);
}

render_frame :: proc(bg_color: sdl.Color) {
    renderer := state.renderer;

    ui_context := &state.ui_context;

    viewport_rect := &sdl.Rect{};
    sdl.GetRendererOutputSize(renderer, &viewport_rect.w, &viewport_rect.h);
    sdl.RenderSetViewport(renderer, viewport_rect);
    sdl.RenderSetClipRect(renderer, viewport_rect);
    sdl.SetRenderDrawColor(renderer, bg_color.r, bg_color.g, bg_color.b, bg_color.a);
    sdl.RenderClear(renderer);

    command_backing: ^mu.Command;
    for variant in mu.next_command_iterator(ui_context, &command_backing) {
        switch cmd in variant {
        case ^mu.Command_Text:
            dst := sdl.Rect{cmd.pos.x, cmd.pos.y, 0, 0};
            for ch in cmd.str do if ch&0xc0 != 0x80 {
                r := min(int(ch), 127);
                src := mu.default_atlas[mu.DEFAULT_ATLAS_FONT + r];
                render_texture(renderer, &dst, src, cmd.color);
                dst.x += dst.w;
            }
        case ^mu.Command_Rect:
            sdl.SetRenderDrawColor(renderer, cmd.color.r, cmd.color.g, cmd.color.b, cmd.color.a);
            sdl.RenderFillRect(renderer, &sdl.Rect{cmd.rect.x, cmd.rect.y, cmd.rect.w, cmd.rect.h});
        case ^mu.Command_Icon:
            src := mu.default_atlas[cmd.id];
            x := cmd.rect.x + (cmd.rect.w - src.w)/2;
            y := cmd.rect.y + (cmd.rect.h - src.h)/2;
            render_texture(renderer, &sdl.Rect{x, y, 0, 0}, src, cmd.color);
        case ^mu.Command_Clip:
            sdl.RenderSetClipRect(renderer, &sdl.Rect{cmd.rect.x, cmd.rect.y, cmd.rect.w, cmd.rect.h});
        case ^mu.Command_Jump:
            unreachable();
        }
    }

    sdl.RenderPresent(renderer);
}

render_texture :: proc(renderer: ^sdl.Renderer, dst: ^sdl.Rect, src: mu.Rect, color: mu.Color) {
    dst.w = src.w;
    dst.h = src.h;

    sdl.SetTextureAlphaMod(state.atlas_texture, color.a);
    sdl.SetTextureColorMod(state.atlas_texture, color.r, color.g, color.b);
    sdl.RenderCopy(renderer, state.atlas_texture, &sdl.Rect{src.x, src.y, src.w, src.h}, dst);
}

take_screenshot :: proc(window: ^sdl.Window) {
    width : i32;
    height : i32;
    sdl.GetRendererOutputSize(state.renderer, &width, &height);

    timestamp := int(time.time_to_unix(time.now()));
    path := fmt.tprintf("./screenshots/screenshot_%i.bmp", timestamp);

    surface := sdl.CreateRGBSurface(0, width, height, 32, 0, 0, 0, 0);
    sdl.RenderReadPixels(state.renderer, {}, surface.format.format, surface.pixels, surface.pitch);
    sdl.SaveBMP(surface, strings.clone_to_cstring(path));
    sdl.FreeSurface(surface);

    logger.write_log("[Renderer] Screenshot taken: %s", path);
}
