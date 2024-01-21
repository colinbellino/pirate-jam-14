package main

import "core:container/queue"
import "core:fmt"
import "core:log"
import "core:mem"
import "core:os"
import "core:path/filepath"
import "core:path/slashpath"
import "core:slice"
import "core:strconv"
import "core:strings"
import "core:time"
import "core:runtime"
import stb_image "vendor:stb/image"
import gl "vendor:OpenGL"
import sdl2 "vendor:sdl2"
import cmd "odin-command"

Pixel :: distinct[4]u8

DEBUG_PADDING   :: #config(DEBUG_PADDING, false)
DIST_FOLDER     :: "dist/"

main :: proc() {
    zone_begin()
    context.logger = log.create_console_logger(.Debug, { .Level, .Terminal_Color, /*.Short_File_Path, .Line , .Procedure */ })

    create_directory(DIST_FOLDER)

    if slice.contains(os.args, "--no-clean") == false {
        clean_build_artifacts()
    }

    if slice.contains(os.args, "--no-libs") == false {
        when ODIN_OS == .Windows {
            copy_file_to_dist("src/sdl2/SDL2.dll", at_root = true)
            copy_file_to_dist("src/sdl2_mixer/SDL2_mixer.dll", at_root = true)
            copy_file_to_dist("src/sdl2_mixer/SDL2_mixer.lib", at_root = true)
            copy_file_to_dist("src/sdl2_mixer/libogg-0.dll", at_root = true)
            copy_file_to_dist("src/odin-imgui/imgui_windows_x64.lib", at_root = true)
            copy_file_to_dist("src/odin-tracy/tracy.lib", at_root = true)
        }
        else when ODIN_OS == .Linux {
            copy_file_to_dist("src/odin-imgui/imgui_linux_x64.a", at_root = true)
            // copy_file_to_dist("src/sdl2/SDL2.lib", at_root = true)
            copy_file_to_dist("src/odin-tracy/tracy.dylib", at_root = true)
        }
        else when ODIN_OS == .Darwin {
            when ODIN_ARCH == .amd64 {
                copy_file_to_dist("src/odin-imgui/imgui_darwin_x64.a", at_root = true)
            } else {
                copy_file_to_dist("src/odin-imgui/imgui_darwin_arm64.a", at_root = true)
            }
            // TODO: Right now, we are using the system libs instead of the one we ship...
            // copy_directory_to_dist("src/sdl2/SDL2.framework", at_root = true)
            // copy_directory_to_dist("src/sdl2/SDL2_mixer.framework", at_root = true)
            copy_file_to_dist("src/odin-tracy/tracy.dylib", at_root = true)
        }
    }

    if slice.contains(os.args, "--no-media") == false {
        create_directory(dist_path_string("media"))

        create_directory(dist_path_string("media/art"))
        process_spritesheet("media/art/spritesheet.png", 16, 16, 0)
        process_spritesheet("media/art/tileset.png", 16, 16, 0)
        process_spritesheet("media/art/Jan.png", 24, 24, 0)
        process_spritesheet("media/art/Adventurer01.png", 32, 32, 0)
        copy_file_to_dist("media/art/test.json")

        create_directory(dist_path_string("media/levels"))
        copy_file_to_dist("media/levels/rooms.ldtk", override = true)

        copy_directory_to_dist("media/audio", override = true)
    }

    if slice.contains(os.args, "--no-shaders") == false {
        files, err := read_directory("media/shaders")
        for file in files {
            compile_shader(filepath.short_stem(file.name))
        }
    }

    log.debugf("Done in %v.", zone_end());
}

create_directory :: proc(path: string) {
    if os.exists(path) {
        return
    }
    error := os.make_directory(path, 0o775)
    if error != 0 {
        log.errorf("- Couldn't create directory: %v", path)
    }
}

copy_directory_to_dist :: proc(path_in: string, path_out: string = "", override: bool = false, at_root: bool = false) {
    zone_begin()
    path_out_final := path_out
    if path_out_final == "" {
        path_out_final = path_in
    }
    if at_root {
        path_out_final = filepath.base(path_out_final)
    }
    path_out_final = dist_path_string(path_out_final)
    defer log.debugf("copy_directory_to_dist: %v -> %v (override: %v, at_root: %v) |> %v", path_in, path_out_final, override, at_root, zone_end())
    if override == false && os.exists(path_out_final) {
        return
    }
    copy_directory(path_in, path_out_final)
}

copy_file_to_dist :: proc(path_in: string, path_out: string = "", override: bool = false, at_root: bool = false) {
    zone_begin()
    path_out_final := path_out
    if path_out_final == "" {
        path_out_final = path_in
    }
    if at_root {
        path_out_final = filepath.base(path_out_final)
    }
    path_out_final = dist_path_string(path_out_final)
    if override == false && os.exists(path_out_final) {
        return
    }
    copy_file(path_in, path_out_final)
    log.debugf("copy_file_to_dist: %v -> %v (override: %v, at_root: %v) |> %v", path_in, path_out_final, override, at_root, zone_end())
}

copy_file :: proc(path_in, path_out: string) {
    data, error := os.read_entire_file_from_filename(path_in, context.temp_allocator)
    if error == false {
        log.errorf("- Couldn't read file: %v", path_in)
        return
    }
    error = os.write_entire_file(path_out, data, true)
    if error == false {
        log.errorf("- Couldn't create file: %v", path_out)
    }
}

copy_directory :: proc(path_in, path_out: string) {
    files, error := read_directory(path_in)
    if error != 0 {
        log.errorf("- Couldn't create directory: %v", path_in)
    }

    if os.is_dir(path_out) == false {
      when ODIN_OS == .Windows {
        // No default value for Windows?
        os.make_directory(path_out, {})
      } else when ODIN_OS == .Linux || ODIN_OS == .Darwin {
        os.make_directory(path_out)
      }
    }

    for file in files {
      copy_to := filepath.join({ path_out, file.name })
      defer delete(copy_to)

      if file.is_dir {
        copy_directory(file.fullpath, copy_to)
      } else {
        copy_file(file.fullpath, copy_to)
      }
    }
}

read_directory :: proc(dir_name: string, allocator := context.allocator) -> ([]os.File_Info, os.Errno) {
    f, err := os.open(dir_name, os.O_RDONLY)
    if err != 0 do return nil, err

    fis: []os.File_Info
    fis, err = os.read_dir(f, -1, allocator)
    os.close(f)

    if err != 0 do return nil, err
    return fis, 0
}

process_spritesheet :: proc(path_in: cstring, sprite_width, sprite_height, padding: int) {
    zone_begin()
    path_out := path_in
    original_width, original_height, original_channels: i32
    original_data := stb_image.load(path_in, &original_width, &original_height, &original_channels, 0)
    original_pixels := transmute([]Pixel) mem.Raw_Slice { data = original_data, len = int(original_width * original_height) }
    // log.debugf("  original:  %vx%v |> %v", original_width, original_height, len(original_pixels))

    new_sprite_width := int(sprite_width + padding * 2)
    new_sprite_height := int(sprite_height + padding * 2)
    new_width := int(original_width) + (int(original_width) / sprite_width * padding * 2)
    new_height := int(original_height) + (int(original_height) / sprite_height * padding * 2)
    new_pixels := make([]Pixel, new_width * new_height)
    slice.fill(new_pixels, Pixel { 0, 0, 0, 0 })
    // log.debugf("  new: %vx%v |> %v", new_width, new_height, len(new_pixels))

    for tile_y := 0; tile_y < new_height / new_sprite_height; tile_y += 1 {
        for tile_x := 0; tile_x < new_width / new_sprite_width; tile_x += 1 {
            // log.debugf("  tile: %vx%v", tile_x, tile_y);

            for inner_y := 0; inner_y < new_sprite_height; inner_y += 1 {
                for inner_x := 0; inner_x < new_sprite_width; inner_x += 1 {
                    new_x := tile_x * new_sprite_width + inner_x
                    new_y := tile_y * new_sprite_height + inner_y
                    new_i := position_to_index(new_x, new_y, new_width, new_height)

                    // log.debugf("  tile: %vx%v | inner: %vx%v", tile_x, tile_y, inner_x, inner_y)
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
                    original_i := position_to_index(original_x, original_y, int(original_width), int(original_height))

                    if original_i > -1 {
                        new_pixels[new_i] = original_pixels[original_i]
                    }
                }
            }
        }
    }

    error := stb_image.write_png(dist_path_cstring(path_out), i32(new_width), i32(new_height), original_channels, &new_pixels[0], i32(new_width) * original_channels)
    if error == 0 {
        log.errorf("- Couldn't write file: %v", path_out)
    }
    log.debugf("process_spritesheet: %v -> %v |> %v", path_in, path_out, zone_end())
}

dist_path_string :: proc(path_out: string, allocator := context.allocator) -> string {
    return slashpath.join({ DIST_FOLDER, string(path_out) }, allocator)
}

dist_path_cstring :: proc(path_out: cstring, allocator := context.temp_allocator) -> cstring {
    path := slashpath.join({ DIST_FOLDER, string(path_out) }, allocator)
    return strings.clone_to_cstring(path, allocator)
}

position_to_index :: proc(x, y, width, height: int) -> int {
    if x < 0 || x > width - 1 || y < 0 || y > height - 1 {
        return -1
    }
    return (y * width) + x
}

clean_build_artifacts :: proc() {
    extensions :: []string { ".dll", ".exe", ".bin", ".exp", ".lib", ".pdb", ".o", ".bin.dSYM" }
    buffer := []u8 { 0, 0 }
    log.debug("clean_build_artifacts:");
    for extension in extensions {
        {
            file := strings.concatenate({ "main", extension })
            path := dist_path_string(file)
            remove_file_or_directory(path)
        }

        for i := 0; i < 99; i += 1 {
            file := strings.concatenate({ "game", strconv.itoa(buffer, i), extension })
            path := dist_path_string(file)
            if os.exists(path) {
                remove_file_or_directory(path)
            }
        }
    }
}

remove_file_or_directory :: proc(path: string) {
    zone_begin()
    if os.is_dir(path) {
        when ODIN_OS == .Darwin {
            os.remove(path)
        } else {
            os.remove_directory(path)
        }
    } else {
        os.remove(path)
    }
    log.debugf("  Deleted %s |> %v", path, zone_end())
}

compile_shader :: proc(name: string) {
    create_directory(fmt.tprintf("src/shaders/%v", name))
    zone_begin()
    path_in := fmt.tprintf("media/shaders/%v.glsl", name)
    path_out := fmt.tprintf("src/shaders/%v/%v.odin", name, name)

    shdc_path := "bin/sokol-shdc"
    when ODIN_OS == .Windows {
        shdc_path = strings.concatenate({ os.get_current_directory(), "/bin/sokol-shdc.exe" }, context.temp_allocator)
    }
    data, ok := cmd.cmd(fmt.tprintf("%v -i %v -o %v -l glsl330 -f sokol_odin", shdc_path, path_in, path_out))
    output := strings.clone_from_bytes(data[:])
    log.debugf("compile_shader: %v -> %v |> %v", path_in, path_out, zone_end())
    if output[0] > 0 {
        fmt.panicf("- Compile error: %v", output)
    }
}

zones := queue.Queue(time.Time) {}
zone_begin :: proc() {
    queue.push_front(&zones, time.now())
}
zone_end :: proc() -> string {
    start := queue.pop_front(&zones)
    duration := time.diff(start, time.now())
    return fmt.tprintf("%v", duration)
}
