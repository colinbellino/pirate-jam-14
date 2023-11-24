package engine

import "core:encoding/json"
import "core:fmt"
import "core:os"

LDTK_Root :: struct {
    iid:                string,
    __header__:         LDTK_Header,
    jsonVersion:        string,
    defs:               LDTK_Definitions,
    levels:             []LDTK_Level,
}

LDTK_Definitions :: struct {
    layers:             []LDTK_Layer,
    entities:           []LDTK_Entity,
    tilesets:           []LDTK_Tileset,
}

LDTK_Header :: struct {
    fileType:   string,
    app:        string,
    doc:        string,
    schema:     string,
    appAuthor:  string,
    appVersion: string,
    url:        string,
}

LDTK_Layer_Uid :: distinct i32
LDTK_Layer :: struct {
    identifier:     string,
    uid:            LDTK_Layer_Uid,
    type:           string,
    gridSize:       i32,
    tilesetDefUid:  LDTK_Tileset_Uid,
}

LDTK_Entity_Uid :: distinct i32
LDTK_Entity :: struct {
    identifier: string,
    uid:        LDTK_Entity_Uid,
    width:      i32,
    height:     i32,
    color:      string,
    tilesetId:  LDTK_Tileset_Uid,
}

LDTK_Tileset_Uid :: distinct i32
LDTK_Tileset :: struct {
    identifier: string,
    uid:        LDTK_Tileset_Uid,
    relPath:    Maybe(string),
}

LDTK_Level_Uid :: distinct i32
LDTK_Level :: struct {
    identifier:     string,
    uid:            LDTK_Level_Uid,
    worldX:         i32,
    worldY:         i32,
    pxWid:          i32,
    pxHei:          i32,
    layerInstances: []LDTK_LayerInstance,
}

LDTK_LayerInstance :: struct {
    iid:                    string,
    levelId:                LDTK_Level_Uid,
    layerDefUid:            LDTK_Layer_Uid,
    gridSize:               i32,
    entityInstances:        []LDTK_EntityInstance,
    intGridCsv:             []i32,
    autoLayerTiles:         []LDTK_Tile_Instance,
    gridTiles:              []LDTK_Tile_Instance,
}

LDTK_EntityInstance :: struct {
    iid:                string,
    width:              i32,
    height:             i32,
    defUid:             LDTK_Entity_Uid,
    __grid:             Vector2i32,
    px:                 Vector2i32,
    fieldInstances:     []LDTK_FieldInstance,
}

LDTK_Field_Id :: distinct i32

LDTK_FieldInstance :: struct {
    __identifier: string,
    __type:       string,
    __value:      json.Value,
    defUid:       LDTK_Field_Id,
}

LDTK_Tile_Id :: distinct i32

LDTK_Tile_Instance :: struct {
    /*
    "Flip bits", a 2-bits integer to represent the mirror transformations of the tile.
    - Bit 0 = X flip
    - Bit 1 = Y flip
    Examples: f=0 (no flip), f=1 (X flip only), f=2 (Y flip only), f=3 (both flips)
    */
    f:      i8,
    /* Pixel coordinates of the tile in the layer ([x,y] format). Don't forget optional layer offsets, if they exist! */
    px:     Vector2i32,
    /* Pixel coordinates of the tile in the tileset ([x,y] format) */
    src:    Vector2i32,
    /* The Tile ID in the corresponding tileset. */
    t:      LDTK_Tile_Id,
}

ldtk_load_file :: proc(path: string, allocator := context.allocator) -> (result: ^LDTK_Root, ok: bool) {
    context.allocator = context.temp_allocator

    result = new(LDTK_Root, allocator)

    data, read_ok := os.read_entire_file(path)

    if read_ok == false {
        fmt.eprintf("No couldn't read file: %v\n", path)
        return
    }

    error := json.unmarshal(data, result, json.DEFAULT_SPECIFICATION)
    if error != nil {
        fmt.eprintf("Unmarshal error: %v\n", error)
        return
    }

    assert(result.jsonVersion == "1.3.4", fmt.tprintf("Invalid json version (expected: 1.3.4, got: %v)", result.jsonVersion))

    ok = true
    return
}
