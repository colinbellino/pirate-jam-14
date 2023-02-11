package engine_ldtk

LDTK :: struct {
    iid:                string,
}

load_file :: proc(path: string) -> LDTK {
    result := LDTK {};
    return result;
}
