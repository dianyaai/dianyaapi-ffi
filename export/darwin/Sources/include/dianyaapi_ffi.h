/* DianyaAPI FFI Bindings - Bridging Header for Swift */
/* 
 * This file is a bridge header that includes the actual FFI header.
 * In development, it references the header in the dianyaapi-ffi/include directory.
 * In distribution, the actual header file is copied to this location as dianyaapi_ffi_original.h
 */

#ifndef dianyaapi_ffi_h
#define dianyaapi_ffi_h

// Try to include from local directory first (distribution)
// Fall back to relative path (development)
#if __has_include("dianyaapi_ffi_original.h")
    // In distribution, the header is copied as dianyaapi_ffi_original.h
    #include "dianyaapi_ffi_original.h"
#else
    // In development, use relative path
    #include "../../../../include/dianyaapi_ffi.h"
#endif

#endif /* dianyaapi_ffi_h */

