package engine_ldtk

import "core:os"
import "core:fmt"
import "core:encoding/json"

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
    uid:        int,
    type:       string,
    gridSize:   int,
    // intGridValues: []any,
    // autoRuleGroups: []any,
}

Entity :: struct {
    identifier: string,
    uid:        int,
    width:      int,
    height:     int,
    color:      string,
    tilesetId:  int,
}

Level :: struct {
    identifier:     string,
    uid:            int,
    worldX:         int,
    worldY:         int,
    pxWid:          int,
    pxHei:          int,
    layerInstances: []LayerInstance,
}

LayerInstance :: struct {
    iid:                string,
    levelId:            int,
    layerDefUid:        int,
    entityInstances:    []EntityInstance,
    intGridCsv:         []int,
    autoLayerTiles:     []Tile,
}

EntityInstance :: struct {
    iid:    string,
    width:  int,
    height: int,
    defUid: int,
    px:     [2]int,
}

Tile :: struct {
    /*
    "Flip bits", a 2-bits integer to represent the mirror transformations of the tile.
    - Bit 0 = X flip
    - Bit 1 = Y flip
    Examples: f=0 (no flip), f=1 (X flip only), f=2 (Y flip only), f=3 (both flips)
    */
    f:      int,
    /* Pixel coordinates of the tile in the layer ([x,y] format). Don't forget optional layer offsets, if they exist! */
    px:     [2]int,
    /* Pixel coordinates of the tile in the tileset ([x,y] format) */
    src:    [2]int,
    /* The Tile ID in the corresponding tileset. */
    t:      int,
}

load_file :: proc(path: string) -> (LDTK, bool) {
    result := LDTK {};

    data, success := os.read_entire_file(path, context.temp_allocator);
    defer delete(data, context.temp_allocator);

    if success == false {
        fmt.eprintf("No couldn't read file: %v\n", path);
        return result, success;
    }

    error := json.unmarshal(data, &result);
    if error != nil {
        fmt.eprintf("Unmarshal error: %v\n", error);
        return result, false;
    }

    assert(result.jsonVersion == "1.2.5",
        fmt.tprintf("Invalid json version (expected: 1.2.5, got: %v)", result.jsonVersion));

    return result, true;
}
