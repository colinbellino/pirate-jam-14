//+build darwin
package tools

import "core:c"
import "core:fmt"
import "core:log"
import "core:mem"
import "core:mem/virtual"
import "core:os"
import "core:runtime"
import "core:sys/darwin"

foreign import libc "System.framework"
foreign libc {
    @(link_name="getrusage") getrusage :: proc "c" (who: c.int, usage : ^rusage) -> c.int ---
}

rusage :: struct {
    ru_utime: darwin.timeval,
    ru_stime: darwin.timeval,
    ru_maxrss: c.long,
    ru_ixrss: c.long,
    ru_idrss: c.long,
    ru_isrss: c.long,
    ru_minflt: c.long,
    ru_majflt: c.long,
    ru_nswap: c.long,
    ru_inblock: c.long,
    ru_oublock: c.long,
    ru_msgsnd: c.long,
    ru_msgrcv: c.long,
    ru_nsignals: c.long,
    ru_nvcsw: c.long,
    ru_nivcsw: c.long,
    other: c.long,
}

@(private="file") _resource_usage_current: rusage
@(private="file") _resource_usage_previous: rusage

mem_get_usage :: proc() -> (c.long, c.long) {
    _resource_usage_previous = _resource_usage_current
    ok := getrusage(0, &_resource_usage_current)
    if ok == -1 {
        log.errorf("getrusage failed.")
        return 0, 0
    }

    return _resource_usage_current.ru_idrss, _resource_usage_previous.ru_idrss
}
