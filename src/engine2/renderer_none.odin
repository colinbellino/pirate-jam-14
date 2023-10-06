package engine2

import "core:log"

renderer_none_init :: proc(window: ^Window) -> (ok: bool) {
    log.infof("No renderer --------------------------------------------")
    return true
}
