if(NOT DEFINED HEADER_FILE)
    message(FATAL_ERROR "HEADER_FILE is not set")
endif()

if(NOT DEFINED TARGET_RELEASE_DIR)
    message(FATAL_ERROR "TARGET_RELEASE_DIR is not set")
endif()

if(NOT DEFINED DIST_DIR)
    message(FATAL_ERROR "DIST_DIR is not set")
endif()

file(MAKE_DIRECTORY "${DIST_DIR}")

file(COPY "${HEADER_FILE}" DESTINATION "${DIST_DIR}")

set(LIB_CANDIDATES
    "${TARGET_RELEASE_DIR}/libdianyaapi_ffi.so"
    "${TARGET_RELEASE_DIR}/libdianyaapi_ffi.dylib"
    "${TARGET_RELEASE_DIR}/libdianyaapi_ffi.a"
    "${TARGET_RELEASE_DIR}/dianyaapi_ffi.dll"
    "${TARGET_RELEASE_DIR}/dianyaapi_ffi.lib"
)

set(COPIED_COUNT 0)
foreach(lib_path IN LISTS LIB_CANDIDATES)
    if(EXISTS "${lib_path}")
        file(COPY "${lib_path}" DESTINATION "${DIST_DIR}")
        math(EXPR COPIED_COUNT "${COPIED_COUNT} + 1")
    endif()
endforeach()

if(COPIED_COUNT EQUAL 0)
    message(WARNING "No dianyaapi_ffi artifacts were found inside ${TARGET_RELEASE_DIR}")
endif()

