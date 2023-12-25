package game

import "core:encoding/json"
import "core:fmt"
import "core:os"
import "core:runtime"

Asset_Unit :: struct {
    name:               string,
    sprite_position:    Vector2i32,
    stat_health_max:    i32,
    stat_speed:         i32,
    stat_move:          i32,
    stat_vision:        i32,
}

load_unit_from_file_path :: proc "contextless" (full_path: string) -> (result: rawptr, ok: bool) {
    context = runtime.default_context()
    context.allocator = _mem.game.arena.allocator

    unit := new(Asset_Unit)

    data, read_ok := os.read_entire_file(full_path)
    if read_ok == false {
        fmt.eprintf("No couldn't read file: %v\n", full_path)
        return
    }

    error := json.unmarshal(data, unit, json.DEFAULT_SPECIFICATION)
    if error != nil {
        fmt.eprintf("Unmarshal error: %v\n", error)
        return
    }

    result = unit
    ok = true
    return
}

print_unit_asset :: proc "contextless" (data: rawptr) -> string {
    context = runtime.default_context()
    return fmt.tprintf("%v", transmute(^Asset_Unit) data)
}

create_unit_from_asset :: proc(asset_id: Asset_Id, asset_info: ^Asset_Unit) -> Unit {
    return Unit {
        asset = asset_id,
        name = asset_info.name,
        sprite_position = asset_info.sprite_position,
        stat_health = asset_info.stat_health_max,
        stat_health_max = asset_info.stat_health_max,
        stat_speed = asset_info.stat_speed,
        stat_move = asset_info.stat_move,
        stat_vision = asset_info.stat_vision,
    }
}

Asset_Ability :: struct {
    name:               string,
    damage:             i32,
    range:              i32,
    push:               i32,
}

load_ability_from_file_path :: proc "contextless" (full_path: string) -> (result: rawptr, ok: bool) {
    context = runtime.default_context()
    context.allocator = _mem.game.arena.allocator

    ability := new(Asset_Ability)

    data, read_ok := os.read_entire_file(full_path)
    if read_ok == false {
        fmt.eprintf("No couldn't read file: %v\n", full_path)
        return
    }

    error := json.unmarshal(data, ability, json.DEFAULT_SPECIFICATION)
    if error != nil {
        fmt.eprintf("Unmarshal error: %v\n", error)
        return
    }

    result = ability
    ok = true
    return
}

print_ability_asset :: proc "contextless" (data: rawptr) -> string {
    context = runtime.default_context()
    return fmt.tprintf("%v", transmute(^Asset_Ability) data)
}

create_ability_from_asset :: proc(asset_id: Asset_Id, asset_info: ^Asset_Ability) -> Ability {
    return Ability {
        asset = asset_id,
        name = asset_info.name,
        damage = asset_info.damage,
        range = asset_info.range,
        push = asset_info.push,
    }
}
