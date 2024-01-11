package shaders

import "core:math/linalg"
import sg "../sokol-odin/sokol/gfx"

Shader_Data     :: #type proc(backend: sg.Backend) -> sg.Shader_Desc

shaders := map[string]Shader_Data {}
