//+build windows
package engine

import "core:c"
import "core:fmt"
import "core:log"
import "core:mem"
import "core:mem/virtual"
import "core:os"
import "core:runtime"
import win32 "core:sys/windows"

timeval :: struct {
    tv_sec:  u32, /* seconds */
    tv_usec: i32, /* microseconds */
}

rusage :: struct {
    ru_utime: timeval,
    ru_stime: timeval,
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

mem_get_usage :: proc() -> (^rusage, ^rusage) {
    _resource_usage_current = rusage {}
    _resource_usage_previous = _resource_usage_current

    return &_resource_usage_current, &_resource_usage_previous
}

_reserve_and_commit_windows :: proc(size: uint, base_address: rawptr = nil) -> (data: []byte, err: runtime.Allocator_Error) {
    result := win32.VirtualAlloc(base_address, size, win32.MEM_RESERVE | win32.MEM_COMMIT, win32.PAGE_READWRITE)

    if result == nil {
        err := win32.GetLastError()
        switch err {
            case 0:
                return nil, .Invalid_Argument
            // case ERROR_INVALID_ADDRESS, ERROR_COMMITMENT_LIMIT:
            //     return nil, .Out_Of_Memory
        }
        return nil, .Out_Of_Memory
    }

    data = ([^]byte)(result)[:size]

    return
}
