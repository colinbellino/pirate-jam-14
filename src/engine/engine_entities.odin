package engine

import "core:math"
import "core:math/ease"
import "core:slice"
import "core:strings"

Entity :: distinct u32

Component_Map :: map[Entity]Component

Component :: struct { }

Component_Name :: struct {
    name:               string,
}

Component_Transform :: struct {
    parent:             Entity,
    position:           Vector2f32,
    scale:              Vector2f32,
    // rotation:           f32,
}

Component_Rendering :: struct {
    visible:            bool,
    texture_asset:      Asset_Id,
    texture_position:   Vector2i32,
    texture_size:       Vector2i32,
    texture_padding:    i32,
    z_index:            i32,
    color:              Color,
}
