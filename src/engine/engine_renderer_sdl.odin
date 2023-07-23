package engine

when RENDERER == .SDL {
    import "core:fmt"
    import "core:log"
    import "core:mem"
    import "vendor:sdl2"

    Renderer_State :: struct {
        using base: Renderer_State_Base,
        renderer:   ^Renderer,
        textures:   [dynamic]^Texture,
    }
    Texture       :: sdl2.Texture

    renderer_init :: proc(window: ^Window, allocator: mem.Allocator, vsync: bool = false) -> (ok: bool) {
        profiler_zone("renderer_init")
        _engine.renderer = new(Renderer_State, allocator)
        _engine.renderer.allocator = allocator
        if PROFILER {
            _engine.renderer.arena = cast(^mem.Arena)(cast(^ProfiledAllocatorData)allocator.data).backing_allocator.data
        } else {
            _engine.renderer.arena = cast(^mem.Arena)allocator.data
        }

        if vsync == false {
            sdl2.SetHint(sdl2.HINT_RENDER_VSYNC, cstring("0"))
        }

        backend_index: i32 = -1
        driver_count := sdl2.GetNumRenderDrivers()
        if driver_count <= 0 {
            log.error("No render drivers available.")
            return
        }
        for i in 0 ..< driver_count {
            info: sdl2.RendererInfo
            driver_error := sdl2.GetRenderDriverInfo(i, &info)
            if driver_error == 0 {
                // NOTE(bill): "direct3d" seems to not work correctly
                if info.name == "opengl" {
                    backend_index = i
                    break
                }
            }
        }

        _engine.renderer.renderer = sdl2.CreateRenderer(window, backend_index, { .ACCELERATED, .PRESENTVSYNC })
        if _engine.renderer.renderer == nil {
            log.errorf("sdl2.CreateRenderer: %v", sdl2.GetError())
            return
        }

        _engine.renderer.enabled = true

        if ui_init() == false {
            log.error("Couldn't ui_init correctly.")
            return
        }
        assert(_engine.ui != nil, "ui not initialized correctly!")

        ok = true
        return
    }

    renderer_quit :: proc() {

    }

    renderer_clear :: proc(color: Color) {
        renderer_set_draw_color(color)
        sdl2.RenderClear(_engine.renderer.renderer)
    }

    renderer_present :: proc() {
        sdl2.RenderPresent(_engine.renderer.renderer)
    }

    renderer_draw_texture_by_index :: proc(texture_index: int, source: ^Rect, destination: ^RectF32, flip: RendererFlip = .NONE, color: Color = { 255, 255, 255, 255 }) {
        assert(texture_index < len(_engine.renderer.textures), fmt.tprintf("Texture out of bounds: %v", texture_index))
        texture := _engine.renderer.textures[texture_index]
        renderer_draw_texture_by_ptr(texture, source, destination, flip, color)
    }

    renderer_draw_texture_by_ptr :: proc(texture: ^Texture, source: ^Rect, destination: ^RectF32, flip: RendererFlip = .NONE, color: Color = { 255, 255, 255, 255 }) {
        _apply_scale(destination, _engine.renderer.rendering_scale)
        _apply_offset(destination, _engine.renderer.rendering_offset)
        _apply_pixel_density(destination, _engine.renderer.pixel_density)
        sdl2.SetTextureAlphaMod(texture, color.a)
        sdl2.SetTextureColorMod(texture, color.r, color.g, color.b)
        sdl2.RenderCopyExF(_engine.renderer.renderer, texture, source, destination, 0, nil, flip)
    }

    renderer_draw_texture_no_offset :: proc(texture: ^Texture, source: ^Rect, destination: ^RectF32, color: Color = { 255, 255, 255, 255 }) {
        _apply_scale(destination, _engine.renderer.rendering_scale)
        _apply_pixel_density(destination, _engine.renderer.pixel_density)
        sdl2.SetTextureAlphaMod(texture, color.a)
        sdl2.SetTextureColorMod(texture, color.r, color.g, color.b)
        sdl2.RenderCopy(_engine.renderer.renderer, texture, source, &{ i32(destination.x), i32(destination.y), i32(destination.w), i32(destination.h) })
    }

    renderer_set_draw_color :: proc(color: Color) -> i32 {
        return sdl2.SetRenderDrawColor(_engine.renderer.renderer, color.r, color.g, color.b, color.a)
    }

    renderer_draw_fill_rect_i32 :: proc(destination: ^Rect, color: Color) {
        destination_f32 := renderer_make_rect_f32(destination.x, destination.y, destination.w, destination.h)
        renderer_draw_fill_rect_f32(&destination_f32, color)
    }

    renderer_draw_fill_rect_f32 :: proc(destination: ^RectF32, color: Color) {
        _apply_scale(destination, _engine.renderer.rendering_scale)
        _apply_offset(destination, _engine.renderer.rendering_offset)
        _apply_pixel_density(destination, _engine.renderer.pixel_density)
        renderer_set_draw_color(color)
        sdl2.SetRenderDrawBlendMode(_engine.renderer.renderer, .BLEND)
        sdl2.RenderFillRectF(_engine.renderer.renderer, destination)
    }

    renderer_draw_fill_rect_no_offset :: proc(destination: ^RectF32, color: Color) {
        _apply_pixel_density(destination, _engine.renderer.pixel_density)
        renderer_set_draw_color(color)
        // TODO: Create rectf32_to_rect
        sdl2.RenderFillRect(_engine.renderer.renderer, &{ i32(destination.x), i32(destination.y), i32(destination.w), i32(destination.h) })
    }

    renderer_draw_fill_rect_raw :: proc(destination: ^RectF32, color: Color) {
        renderer_set_draw_color(color)
        sdl2.RenderFillRectF(_engine.renderer.renderer, destination)
    }

    renderer_make_rect_f32 :: proc(x, y, w, h: i32) -> RectF32 {
        return RectF32 { f32(x), f32(y), f32(w), f32(h) }
    }

    renderer_set_clip_rect :: proc(rect: ^Rect) {
        sdl2.RenderSetClipRect(_engine.renderer.renderer, rect)
    }

    // renderer_take_screenshot :: proc(window: ^Window) {
    //     width : i32
    //     height : i32
    //     sdl2.GetRendererOutputSize(_engine.renderer.renderer, &width, &height)

    //     timestamp := int(time.time_to_unix(time.now()))
    //     path := fmt.tprintf("./screenshots/screenshot_%i.bmp", timestamp)

    //     surface := sdl2.CreateRGBSurface(0, width, height, 32, 0, 0, 0, 0)
    //     sdl2.RenderReadPixels(_engine.renderer.renderer, {}, surface.format.format, surface.pixels, surface.pitch)
    //     c_path := strings.clone_to_cstring(path)
    //     defer delete(c_path)
    //     sdl2.SaveBMP(surface, c_path)
    //     sdl2.FreeSurface(surface)

    //     log.debugf("Screenshot taken: %s", path)
    // }

    renderer_read_pixels :: proc(rect: ^Rect, format: sdl2.PixelFormatEnum, pixels: rawptr, pitch: i32) {
        result := sdl2.RenderReadPixels(_engine.renderer.renderer, rect, u32(format), pixels, pitch)
        if result < 0 {
            log.errorf("RenderReadPixels error: %v", sdl2.GetError())
        }
    }

    renderer_create_texture_from_surface :: proc (surface: ^Surface) -> (texture: ^Texture, texture_index: int = -1, ok: bool) {
        texture = sdl2.CreateTextureFromSurface(_engine.renderer.renderer, surface)
        if texture == nil {
            log.errorf("Couldn't convert image to texture.")
            return
        }

        append(&_engine.renderer.textures, texture)
        texture_index = len(_engine.renderer.textures) - 1
        ok = true
        // log.debugf("renderer_create_texture_from_surface: %v -> %v", texture_index, texture)
        return
    }

    renderer_create_texture :: proc(pixel_format: u32, texture_access: TextureAccess, width: i32, height: i32) -> (texture: ^Texture, texture_index: int = -1, ok: bool) {
        context.allocator = _engine.renderer.allocator

        texture = sdl2.CreateTexture(_engine.renderer.renderer, pixel_format, texture_access, width, height)
        if texture == nil {
            log.errorf("Couldn't create texture.")
        }

        append(&_engine.renderer.textures, texture)
        texture_index = len(_engine.renderer.textures) - 1
        ok = true
        // log.debugf("renderer_create_texture: %v -> %v", texture_index, texture)
        return
    }

    renderer_set_texture_blend_mode :: proc(texture: ^Texture, blend_mode: BlendMode) -> (error: i32) {
        error = sdl2.SetTextureBlendMode(texture, blend_mode)
        return
    }

    renderer_update_texture :: proc(texture: ^Texture, rect: ^Rect, pixels: rawptr, pitch: i32) -> (error: i32) {
        error = sdl2.UpdateTexture(texture, rect, pixels, pitch)
        return
    }

    renderer_get_window_pixel_density :: proc(window: ^Window) -> f32 {
        window_size := platform_get_window_size(window)
        output_width : i32 = 0
        output_height : i32 = 0
        sdl2.GetRendererOutputSize(_engine.renderer.renderer, &output_width, &output_height)
        return f32(output_width / window_size.x)
    }

    renderer_draw_line :: proc(pos1: ^Vector2i32, pos2: ^Vector2i32) -> i32 {
        _apply_scale(pos1, _engine.renderer.rendering_scale)
        _apply_offset(pos1, _engine.renderer.rendering_offset)
        _apply_pixel_density(pos1, _engine.renderer.pixel_density)
        _apply_scale(pos2, _engine.renderer.rendering_scale)
        _apply_offset(pos2, _engine.renderer.rendering_offset)
        _apply_pixel_density(pos2, _engine.renderer.pixel_density)
        return sdl2.RenderDrawLine(_engine.renderer.renderer, pos1.x, pos1.y, pos2.x, pos2.y)
    }

    renderer_query_texture :: proc(texture: ^Texture, width, height: ^i32) -> i32 {
        return sdl2.QueryTexture(texture, nil, nil, width, height)
    }

    renderer_set_render_target :: proc(texture: ^Texture) -> i32 {
        return sdl2.SetRenderTarget(_engine.renderer.renderer, texture)
    }

    renderer_is_enabled :: proc() -> bool {
        return _engine.renderer != nil && _engine.renderer.enabled
    }

    // Order of the apply_* calls is import: scale -> offset -> pixel_density

    @(private="file")
    _apply_scale :: proc {
        _apply_scale_rect,
        _apply_scale_vector2,
    }
    @(private="file")
    _apply_scale_rect :: proc(rect: ^RectF32, scale: i32) {
        rect.x *= f32(scale)
        rect.y *= f32(scale)
        rect.w *= f32(scale)
        rect.h *= f32(scale)
    }
    @(private="file")
    _apply_scale_vector2 :: proc(vec: ^Vector2i32, scale: i32) {
        vec.x *= scale
        vec.y *= scale
    }

    @(private="file")
    _apply_offset :: proc {
        _apply_offset_rectf32,
        _apply_offset_vector2i,
    }
    @(private="file")
    _apply_offset_rectf32 :: proc(rect: ^RectF32, offset: Vector2i32) {
        rect.x += f32(offset.x)
        rect.y += f32(offset.y)
    }
    @(private="file")
    _apply_offset_vector2i :: proc(vec: ^Vector2i32, offset: Vector2i32) {
        vec.x += offset.x
        vec.y += offset.y
    }

    @(private="file")
    _apply_pixel_density :: proc {
        _apply_pixel_density_rectf32,
        _apply_pixel_density_vector2i,
    }
    @(private="file")
    _apply_pixel_density_rectf32 :: proc(rect: ^RectF32, pixel_density: f32) {
        assert(pixel_density != 0.0, "pixel_density is invalid (0.0).")
        rect.x *= pixel_density
        rect.y *= pixel_density
        rect.w *= pixel_density
        rect.h *= pixel_density
    }
    @(private="file")
    _apply_pixel_density_vector2i :: proc(vec: ^Vector2i32, pixel_density: f32) {
        assert(pixel_density != 0.0, "pixel_density is invalid (0.0).")
        vec.x = i32(f32(vec.x) * pixel_density)
        vec.y = i32(f32(vec.y) * pixel_density)
    }
}
