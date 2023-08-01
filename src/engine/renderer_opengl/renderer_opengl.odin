package renderer_opengl

import "core:log"
import "core:math"
import "core:mem"
import "core:os"
import "core:strings"
import gl "vendor:OpenGL"

Shader :: struct #packed {
    renderer_id:            u32,
    uniform_location_cache: map[string]i32,
    filepath:               string,
    vertex:                 string,
    fragment:               string,
}
Shader_Types :: enum { None = -1, Vertex = 0, Fragment = 1 }

shader_load :: proc(shader: ^Shader, filepath: string, binary_retrievable := false) -> (ok: bool) {
    data : []byte
    data, ok = os.read_entire_file(filepath, context.temp_allocator)
    if ok == false {
        log.errorf("Shader file couldn't be read: %v", filepath)
        return
    }

    log.debugf("Loading shader: %v", filepath)

    builders := [2]strings.Builder {}
    type := Shader_Types.None
    it := string(data)
    for line in strings.split_lines_iterator(&it) {
        if strings.has_prefix(line, "#shader") {
            if strings.contains(line, "vertex") {
                type = .Vertex
            } else if strings.contains(line, "fragment") {
                type = .Fragment
            }
            strings.write_rune(&builders[type], '/')
            strings.write_rune(&builders[type], '/')
            strings.write_string(&builders[type], line)
            strings.write_rune(&builders[type], '\n')

            // log.debugf("  %v", type)
            // log.debugf("  ----------------------------------------------------------")
        } else {
            if type == .None {
                continue
            }
            strings.write_string(&builders[type], line)
            strings.write_rune(&builders[type], '\n')
        }
    }

    vertex := strings.to_string(builders[Shader_Types.Vertex])
    fragment := strings.to_string(builders[Shader_Types.Fragment])
    // log.debugf("vertex -----------------------------------------------------\n%v", vertex);
    // log.debugf("fragment ---------------------------------------------------\n%v", fragment);

    // when RENDERER_DEBUG {
    //     shader.filepath = filepath
    //     shader.vertex = vertex
    //     shader.fragment = fragment
    // }
    shader.renderer_id, ok = gl.load_shaders_source(vertex, fragment, binary_retrievable)

    return
}
