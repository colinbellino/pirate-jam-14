package engine_ldtk

import "core:encoding/json"
import "core:fmt"
import "core:os"
import "core:runtime"

import "../math"

LDTK :: struct {
    iid:                string,
    // __header__:         Header,
    jsonVersion:        string,
    defs:               Definitions,
    levels:             []Level,
}

Definitions :: struct {
    layers:             []Layer,
    entities:           []Entity,
}

Header :: struct {
    fileType:   string,
    app:        string,
    doc:        string,
    schema:     string,
    appAuthor:  string,
    appVersion: string,
    url:        string,
}

Layer :: struct {
    identifier: string,
    uid:        i32,
    type:       string,
    gridSize:   i32,
    // intGridValues: []any,
    // autoRuleGroups: []any,
}

Entity :: struct {
    identifier: string,
    uid:        i32,
    width:      i32,
    height:     i32,
    color:      string,
    tilesetId:  i32,
}

Level :: struct {
    identifier:     string,
    uid:            i32,
    worldX:         i32,
    worldY:         i32,
    pxWid:          i32,
    pxHei:          i32,
    layerInstances: []LayerInstance,
}

LayerInstance :: struct {
    iid:                string,
    levelId:            i32,
    layerDefUid:        i32,
    gridSize:           i32,
    entityInstances:    []EntityInstance,
    intGridCsv:         []i32,
    autoLayerTiles:     []Tile,
}

EntityInstance :: struct {
    iid:        string,
    width:      i32,
    height:     i32,
    defUid:     i32,
    __grid:     math.Vector2i,
    px:         math.Vector2i,
}

Tile :: struct {
    /*
    "Flip bits", a 2-bits integer to represent the mirror transformations of the tile.
    - Bit 0 = X flip
    - Bit 1 = Y flip
    Examples: f=0 (no flip), f=1 (X flip only), f=2 (Y flip only), f=3 (both flips)
    */
    f:      i32,
    /* Pixel coordinates of the tile in the layer ([x,y] format). Don't forget optional layer offsets, if they exist! */
    px:     math.Vector2i,
    /* Pixel coordinates of the tile in the tileset ([x,y] format) */
    src:    math.Vector2i,
    /* The Tile ID in the corresponding tileset. */
    t:      i32,
}

load_file :: proc(path: string, allocator: runtime.Allocator = context.allocator) -> (result: LDTK, ok: bool) {
    context.allocator = allocator;

    result = LDTK {};

    data, read_ok := os.read_entire_file(path);
    defer delete(data);

    if read_ok == false {
        fmt.eprintf("No couldn't read file: %v\n", path);
        return;
    }

    error := json.unmarshal(data, &result, json.DEFAULT_SPECIFICATION);
    if error != nil {
        fmt.eprintf("Unmarshal error: %v\n", error);
        return;
    }

    assert(result.jsonVersion == "1.2.5",
        fmt.tprintf("Invalid json version (expected: 1.2.5, got: %v)", result.jsonVersion));

    ok = true;
    return;
}
