package engine2

import "core:log"

Renderers :: enum { None, OpenGL }

Renderer_Procs :: struct {
    init:   proc(window: ^Window) -> (ok: bool),
    deinit: proc(),
}

Renderer :: struct {
    renderer:   Renderers,
    procs:      Renderer_Procs,
    data:       rawptr,
}

@(private="package")
r: ^Renderer

renderer_init :: proc(renderer: Renderers, window: ^Window) -> (_r: ^Renderer, ok: bool) {
    r = new(Renderer)
    switch_renderer(renderer)
    if r.procs.init != nil {
        ok = r.procs.init(window)
        if ok == false {
            log.errorf("renderer init error")
            return
        }
    }
    return r, true
}

renderer_deinit :: proc() {
    if r.procs.deinit != nil {
        r.procs.deinit()
    }
    free(r)
}

switch_renderer :: proc(renderer: Renderers) {
    switch renderer {
        case .None: {
            r.procs.init = renderer_none_init
        }
        case .OpenGL: {
            r.procs.init = renderer_opengl_init
            r.procs.deinit = renderer_opengl_deinit
        }
    }
    r.renderer = renderer
    r.data = nil
}
