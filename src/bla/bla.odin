package bla

import "core:c"
import "core:dynlib"
import "core:fmt"
import "core:log"
import "core:mem"
import "core:mem/virtual"
import "core:os"
import "core:runtime"

foreign import libc "System.framework"
foreign libc {
    @(link_name="mmap")             _mmap               :: proc(addr: rawptr, len: c.size_t, prot: c.int, flags: c.int, fd: c.int, offset: int) -> rawptr ---
    @(link_name="mprotect")         _mprotect           :: proc(addr: rawptr, len: c.size_t, prot: c.int) -> c.int ---
}

PROT_NONE  :: 0x0 /* [MC2] no permissions */
PROT_READ  :: 0x1 /* [MC2] pages can be read */
PROT_WRITE :: 0x2 /* [MC2] pages can be written */
PROT_EXEC  :: 0x4 /* [MC2] pages can be executed */

// Sharing options
MAP_SHARED    :: 0x1 /* [MF|SHM] share changes */
MAP_PRIVATE   :: 0x2 /* [MF|SHM] changes are private */

// Other flags
MAP_FIXED        :: 0x0010 /* [MF|SHM] interpret addr exactly */
MAP_RENAME       :: 0x0020 /* Sun: rename private pages to file */
MAP_NORESERVE    :: 0x0040 /* Sun: don't reserve needed swap area */
MAP_RESERVED0080 :: 0x0080 /* previously unimplemented MAP_INHERIT */
MAP_NOEXTEND     :: 0x0100 /* for MAP_FILE, don't change file size */
MAP_HASSEMAPHORE :: 0x0200 /* region may contain semaphores */
MAP_NOCACHE      :: 0x0400 /* don't cache pages for this mapping */
MAP_JIT          :: 0x0800 /* Allocate a region that will be used for JIT purposes */

// Mapping type
MAP_FILE         :: 0x0000  /* map from file (default) */
MAP_ANONYMOUS    :: 0x1000  /* allocated from memory, swap space */

// Allocation failure result
MAP_FAILED : rawptr = rawptr(~uintptr(0))

reserve_darwin :: proc "contextless" (size: uint, base_address: rawptr = nil) -> (data: []byte, err: runtime.Allocator_Error) {
    result := _mmap(base_address, size, PROT_NONE, MAP_ANONYMOUS | MAP_SHARED | MAP_FIXED, -1, 0);
    if result == MAP_FAILED {
        return nil, .Out_Of_Memory
    }
    return ([^]byte)(uintptr(result))[:size], nil
}

commit_darwin :: proc "contextless" (data: rawptr, size: uint) -> runtime.Allocator_Error {
    result := _mprotect(data, size, PROT_READ | PROT_WRITE)
    if result != 0 {
        return .Out_Of_Memory
    }
    return nil
}

reserve_and_commit :: proc "contextless" (size: uint, base_address: rawptr = nil) -> (data: []byte, err: runtime.Allocator_Error) {
    when ODIN_OS == .Windows {
        data = reserve_darwin(size, base_address) or_return
        commit_darwin(raw_data(data), size) or_return
    } else when ODIN_OS == .Darwin {
        data = reserve_darwin(size, base_address) or_return
        commit_darwin(raw_data(data), size) or_return
    } else {
        fmt.eprintf("OS not supported: %v.\b", ODIN_OS);
        os.exit(1);
    }
    return
}

Memory_Marker :: struct #packed {
    a0:     u8,
    a1:     u8,
    a2:     u8,
    a3:     u8,
    a4:     u8,
    a5:     u8,
    a6:     u8,
    a7:     u8,
    a8:     u8,
    a9:     u8,
    a10:     u8,
    a11:     u8,
    a12:     u8,
    a13:     u8,
    a14:     u8,
    a15:     u8,
}
