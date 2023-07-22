package main

import "core:bytes"
import "core:fmt"
import "core:image"
import "core:log"
import "core:mem"
import "core:os"
import "core:slice"
import "core:strings"
import "core:time"
import stb_image "vendor:stb/image"

import engine "engine"

Pixel :: distinct[4]u8

DEBUG_PADDING :: #config(DEBUG_PADDING, false)

main :: proc() {
    context.logger = log.create_console_logger(.Debug, { /*.Level, .Terminal_Color, .Short_File_Path, .Line , .Procedure */ })

    log.debugf("Process assets:");

    process_spritesheet("media/art/spritesheet.png", "dist/media/art/spritesheet.processed.png", 8, 8, 1)
    process_spritesheet("media/art/nyan.png", "dist/media/art/nyan.processed.png", 40, 32, 10)
}

process_spritesheet :: proc(path_in, path_out: cstring, sprite_width, sprite_height, padding: int) {
    original_width, original_height, original_channels: i32
    original_data := stb_image.load(path_in, &original_width, &original_height, &original_channels, 0)
    original_pixels := transmute([]Pixel) mem.Raw_Slice { data = original_data, len = int(original_width * original_height) }
    // log.debugf("original:  %vx%v | %v", original_width, original_height, len(original_pixels))

    new_sprite_width := int(sprite_width + padding * 2)
    new_sprite_height := int(sprite_height + padding * 2)
    new_width := int(original_width) + (int(original_width) / sprite_width * padding * 2)
    new_height := int(original_height) + (int(original_height) / sprite_height * padding * 2)
    new_pixels := make([]Pixel, new_width * new_height)
    slice.fill(new_pixels, Pixel { 0, 0, 0, 0 })
    log.debugf("new: %vx%v | %v", new_width, new_height, len(new_pixels))

    for tile_y := 0; tile_y < new_height / new_sprite_height; tile_y += 1 {
        for tile_x := 0; tile_x < new_width / new_sprite_width; tile_x += 1 {
            // log.debugf("tile: %vx%v", tile_x, tile_y);

            for inner_y := 0; inner_y < new_sprite_height; inner_y += 1 {
                for inner_x := 0; inner_x < new_sprite_width; inner_x += 1 {
                    new_x := tile_x * new_sprite_width + inner_x
                    new_y := tile_y * new_sprite_height + inner_y
                    new_i := position_to_index(new_x, new_y, new_width, new_height)

                    // log.debugf("tile: %vx%v | inner: %vx%v", tile_x, tile_y, inner_x, inner_y)
                    x := inner_x
                    y := inner_y
                    if inner_x < padding {
                        when DEBUG_PADDING { new_pixels[new_i] = { 255, 0, 0, 255 }; continue; }
                        x = clamp(padding, 0, new_sprite_width - 1)
                    }
                    else if inner_x > sprite_width + padding - 1 {
                        when DEBUG_PADDING { new_pixels[new_i] = { 0, 255, 0, 255 }; continue; }
                        x = clamp(sprite_width + padding - 1, 0, new_sprite_width - 1)
                    }
                    if inner_y < padding {
                        when DEBUG_PADDING { new_pixels[new_i] = { 0, 0, 255, 255 }; continue; }
                        y = clamp(padding, 0, new_sprite_height - 1)
                    }
                    else if inner_y > sprite_height + padding - 1 {
                        when DEBUG_PADDING { new_pixels[new_i] = { 255, 255, 0, 255 }; continue; }
                        y = clamp(sprite_height + padding - 1, 0, new_sprite_height - 1)
                    }

                    original_x := tile_x * sprite_width + x - padding
                    original_y := tile_y * sprite_height + y - padding
                    {
                        // FIXME: crappy hack specific to stylesheet.original.png, remove this
                        if original_x == 38 && original_y >= 73 && original_y <= 78 { original_x += 1 }
                        if original_x == 49 && original_y >= 73 && original_y <= 78 { original_x -= 1 }
                        if original_x >= 41 && original_x <= 46 && original_y == 70 { original_y += 1 }
                        if original_x >= 41 && original_x <= 46 && original_y == 81 { original_y -= 1 }
                    }
                    original_i := position_to_index(original_x, original_y, int(original_width), int(original_height))

                    if original_i > -1 {
                        new_pixels[new_i] = original_pixels[original_i]
                    }
                }
            }
        }
    }

    stb_image.write_png(path_out, i32(new_width), i32(new_height), original_channels, &new_pixels[0], i32(new_width) * original_channels)
    log.debugf("  Created: %v", path_out)
}

position_to_index :: proc(x, y, width, height: int) -> int {
    if x < 0 || x > width - 1 || y < 0 || y > height - 1 {
        return -1
    }
    return (y * width) + x
}
