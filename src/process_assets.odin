package main

import "core:log"
import "core:fmt"
import "core:mem"
import "core:os"
import "core:time"
import "core:image"
import "core:bytes"
import "core:slice"
import stb_image "vendor:stb/image"

import engine "engine"

Pixel :: distinct[4]u8

main :: proc() {
    context.logger = log.create_console_logger(.Debug, { /*.Level, .Terminal_Color, .Short_File_Path, .Line , .Procedure */ })

    log.debugf("Process assets:");

    original_width, original_height, original_channels: i32
    original_data := stb_image.load("media/art/spritesheet.png", &original_width, &original_height, &original_channels, 0)
    original_pixels := transmute([]Pixel) mem.Raw_Slice { data = original_data, len = int(original_width * original_height) }
    // log.debugf("original:  %vx%v | %v", original_width, original_height, len(original_pixels))

    tile_size := 8
    padding := 1
    new_tile_size := int(tile_size + padding * 2)

    processed_width := int(original_width) + (int(original_width) / tile_size * padding * 2)
    processed_height := int(original_height) + (int(original_height) / tile_size * padding * 2)
    processed_pixels := make([]Pixel, processed_width * processed_height)
    slice.fill(processed_pixels, Pixel { 0, 0, 0, 255 })
    // log.debugf("processed: %vx%v | %v", processed_width, processed_height, len(processed_pixels))

    for tile_y := 0; tile_y < processed_height / new_tile_size; tile_y += 1 {
        for tile_x := 0; tile_x < processed_width / new_tile_size; tile_x += 1 {
            // log.debugf("tile: %vx%v", tile_x, tile_y);

            for inner_y := 0; inner_y < new_tile_size; inner_y += 1 {
                for inner_x := 0; inner_x < new_tile_size; inner_x += 1 {
                    processed_x := tile_x * new_tile_size + inner_x
                    processed_y := tile_y * new_tile_size + inner_y
                    processed_i := position_to_index(processed_x, processed_y, processed_width, processed_height)

                    // log.debugf("tile: %vx%v | inner: %vx%v", tile_x, tile_y, inner_x, inner_y)
                    x := inner_x
                    y := inner_y

                    if inner_x == 0 {
                        x = clamp(x + 1, 0, new_tile_size - 1)
                    }
                    else if inner_x == new_tile_size - 1 {
                        x = clamp(x - 1, 0, new_tile_size - 1)
                    }
                    if inner_y == 0 {
                        y = clamp(y + 1, 0, new_tile_size - 1)
                    }
                    else if inner_y == new_tile_size - 1 {
                        y = clamp(y - 1, 0, new_tile_size - 1)
                    }

                    original_x := tile_x * tile_size + x - 1
                    original_y := tile_y * tile_size + y - 1
                    {
                        // FIXME: crappy hack specific to stylesheet.original.png, remove this
                        if original_x == 38 && original_y >= 73 && original_y <= 78 { original_x += 1 }
                        if original_x == 49 && original_y >= 73 && original_y <= 78 { original_x -= 1 }
                        if original_x >= 41 && original_x <= 46 && original_y == 70 { original_y += 1 }
                        if original_x >= 41 && original_x <= 46 && original_y == 81 { original_y -= 1 }
                    }
                    original_i := position_to_index(original_x, original_y, int(original_width), int(original_height))

                    if original_i > -1 {
                        processed_pixels[processed_i] = original_pixels[original_i]
                    }
                }
            }
        }
    }

    stb_image.write_png("dist/media/art/spritesheet.processed.png", i32(processed_width), i32(processed_height), original_channels, &processed_pixels[0], i32(processed_width) * original_channels)
    log.debugf("  Created: dist/media/art/spritesheet.processed.png")
}

position_to_index :: proc(x, y, width, height: int) -> int {
    if x < 0 || x > width - 1 || y < 0 || y > height - 1 {
        return -1
    }
    return (y * width) + x
}
