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
    @(link_name="getrusage")        getrusage           :: proc "c" (who: c.int, usage : ^rusage) -> c.int ---
}

rusage :: struct {
    ru_utime: darwin.timeval,
    ru_stime: darwin.timeval,
    ru_maxrss: u64,
    ru_ixrss: u64,
    ru_idrss: u64,
    ru_isrss: u64,
    ru_minflt: u64,
    ru_majflt: u64,
    ru_nswap: u64,
    ru_inblock: u64,
    ru_oublock: u64,
    ru_msgsnd: u64,
    ru_msgrcv: u64,
    ru_nsignals: u64,
    ru_nvcsw: u64,
    ru_nivcsw: u64,
    other: u64,
}

@(private="file") _resource_usage_current: rusage
@(private="file") _resource_usage_previous: rusage

mem_get_usage :: proc() -> (u64, u64) {
    _resource_usage_previous = _resource_usage_current
    ok := getrusage(0, &_resource_usage_current)
    if ok == -1 {
        log.errorf("getrusage failed.")
    }

    return _resource_usage_current.ru_idrss, _resource_usage_previous.ru_idrss
}
