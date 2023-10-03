//+build windows
package engine

import "core:c"
import "core:fmt"
import "core:log"
import "core:mem"
import "core:mem/virtual"
import "core:os"
import "core:runtime"
import "core:sys/windows"

foreign import kernel32 "system:Kernel32.lib"

@(default_calling_convention="stdcall")
foreign kernel32 {
    _getpid              :: proc() -> windows.DWORD ---
    OpenProcess          :: proc(dwDesiredAccess: windows.DWORD, bInheritHandle: bool, dwProcessId: windows.DWORD) -> windows.HANDLE ---
    K32GetProcessMemoryInfo :: proc(Process: windows.HANDLE, ppsmemCounters: ^PROCESS_MEMORY_COUNTERS, cb: windows.DWORD) -> bool ---
}

PROCESS_QUERY_INFORMATION : windows.DWORD : 0x0400
PROCESS_VM_READ           : windows.DWORD : 0x0010

PROCESS_MEMORY_COUNTERS :: struct {
    cb:                         windows.DWORD,
    PageFaultCount:             windows.DWORD,
    PeakWorkingSetSize:         windows.SIZE_T,
    WorkingSetSize:             windows.SIZE_T,
    QuotaPeakPagedPoolUsage:    windows.SIZE_T,
    QuotaPagedPoolUsage:        windows.SIZE_T,
    QuotaPeakNonPagedPoolUsage: windows.SIZE_T,
    QuotaNonPagedPoolUsage:     windows.SIZE_T,
    PagefileUsage:              windows.SIZE_T,
    PeakPagefileUsage:          windows.SIZE_T,
}

@(private="file") _resource_usage_current: PROCESS_MEMORY_COUNTERS = {}
@(private="file") _resource_usage_previous: PROCESS_MEMORY_COUNTERS = {}

mem_get_usage :: proc() -> (u64, u64) {
    pid := _getpid()
    handle := OpenProcess(PROCESS_QUERY_INFORMATION, false, pid)
    if handle != nil {
        defer windows.CloseHandle(handle)
        _resource_usage_previous = _resource_usage_current
        ok := K32GetProcessMemoryInfo(handle, &_resource_usage_current, size_of(_resource_usage_previous))
        // ui_text("pmc: %#v", &_resource_usage_previous)
        if _resource_usage_current.WorkingSetSize != _resource_usage_previous.WorkingSetSize {
            log.debugf("allocated: %v | %#v", _resource_usage_current.WorkingSetSize - _resource_usage_previous.WorkingSetSize, _resource_usage_previous)
        }
    }

    return u64(_resource_usage_current.WorkingSetSize), u64( _resource_usage_previous.WorkingSetSize)
}
