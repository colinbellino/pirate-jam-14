package renderer

import "core:fmt"
import "core:log"
import "core:runtime"
import "core:strconv"
import "core:strings"
import "core:time"
import sdl "vendor:sdl2"
import mu "vendor:microui"

import platform "../platform"

Color :: sdl.Color;
Texture :: sdl.Texture;
Rect :: sdl.Rect;
Window :: sdl.Window;
Renderer :: sdl.Renderer;

destroy_texture :: sdl.DestroyTexture;

State :: struct {
    renderer:       ^Renderer,
    ui_context:     mu.Context,
    atlas_texture:  ^Texture,
    textures:       [dynamic]^Texture,
}

state := State {};

init :: proc(window: ^Window) {
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

    mu.init(&state.ui_context);
    state.ui_context.text_width = mu.default_atlas_text_width;
    state.ui_context.text_height = mu.default_atlas_text_height;
}

quit :: proc() {
    sdl.DestroyRenderer(state.renderer);
}

clear :: proc(color: Color) {
    viewport_rect := &Rect{};
    sdl.GetRendererOutputSize(state.renderer, &viewport_rect.w, &viewport_rect.h);
    sdl.RenderSetViewport(state.renderer, viewport_rect);
    sdl.RenderSetClipRect(state.renderer, viewport_rect);
    sdl.SetRenderDrawColor(state.renderer, color.r, color.g, color.b, color.a);
    sdl.RenderClear(state.renderer);
}

process_ui_commands :: proc() {
    command_backing: ^mu.Command;
    for variant in mu.next_command_iterator(&state.ui_context, &command_backing) {
        switch cmd in variant {
            case ^mu.Command_Text: {
                dst := Rect{cmd.pos.x, cmd.pos.y, 0, 0};
                for ch in cmd.str do if ch&0xc0 != 0x80 {
                    r := min(int(ch), 127);
                    src := mu.default_atlas[mu.DEFAULT_ATLAS_FONT + r];
                    ui_render_atlas_texture(state.renderer, &dst, src, cmd.color);
                    dst.x += dst.w;
                }
            }
            case ^mu.Command_Rect: {
                sdl.SetRenderDrawColor(state.renderer, cmd.color.r, cmd.color.g, cmd.color.b, cmd.color.a);
                sdl.RenderFillRect(state.renderer, &Rect{cmd.rect.x, cmd.rect.y, cmd.rect.w, cmd.rect.h});
            }
            case ^mu.Command_Icon: {
                src := mu.default_atlas[cmd.id];
                x := cmd.rect.x + (cmd.rect.w - src.w)/2;
                y := cmd.rect.y + (cmd.rect.h - src.h)/2;
                ui_render_atlas_texture(state.renderer, &Rect{x, y, 0, 0}, src, cmd.color);
            }
            case ^mu.Command_Clip:
                sdl.RenderSetClipRect(state.renderer, &Rect{cmd.rect.x, cmd.rect.y, cmd.rect.w, cmd.rect.h});
            case ^mu.Command_Jump:
                unreachable();
        }
    }
}

present :: proc() {
    sdl.RenderPresent(state.renderer);
}

ui_render_atlas_texture :: proc(renderer: ^Renderer, dst: ^Rect, src: mu.Rect, color: mu.Color) {
    dst.w = src.w;
    dst.h = src.h;

    sdl.SetTextureAlphaMod(state.atlas_texture, color.a);
    sdl.SetTextureColorMod(state.atlas_texture, color.r, color.g, color.b);
    sdl.RenderCopy(renderer, state.atlas_texture, &Rect{src.x, src.y, src.w, src.h}, dst);
}

draw_texture :: proc(texture_index: int, source_rect: ^Rect, destination_rect: ^Rect) {
    assert(texture_index < len(state.textures), fmt.tprintf("Texture out of bounds: %v", texture_index));
    texture := state.textures[texture_index];
    sdl.RenderCopy(state.renderer, texture, source_rect, destination_rect);
}

// draw_sprite :: proc(texture_index: int, source_rect: ^Rect, destination_rect: ^Rect) {
//     draw_texture(texture_index, source_rect, destination_rect);
// }

take_screenshot :: proc(window: ^Window) {
    width : i32;
    height : i32;
    sdl.GetRendererOutputSize(state.renderer, &width, &height);

    timestamp := int(time.time_to_unix(time.now()));
    path := fmt.tprintf("./screenshots/screenshot_%i.bmp", timestamp);

    surface := sdl.CreateRGBSurface(0, width, height, 32, 0, 0, 0, 0);
    sdl.RenderReadPixels(state.renderer, {}, surface.format.format, surface.pixels, surface.pitch);
    sdl.SaveBMP(surface, strings.clone_to_cstring(path));
    sdl.FreeSurface(surface);

    log.debugf("[Renderer] Screenshot taken: %s", path);
}

create_texture_from_surface :: proc (surface: ^platform.Surface) -> (texture: ^Texture, ok: bool) {
    texture = sdl.CreateTextureFromSurface(state.renderer, surface);
    if texture == nil {
        log.errorf("Couldn't convert image to texture.");
        return;
    }

    ok = true;
    return;
}
