cmake_minimum_required(VERSION 3.16)
project(dianyaapi_go_bindings LANGUAGES C)

find_program(CARGO_EXECUTABLE cargo REQUIRED)
find_program(GO_EXECUTABLE go REQUIRED)

set(REPO_ROOT "${CMAKE_CURRENT_LIST_DIR}/../..")
set(WRAPPER_FFI_DIR "${CMAKE_CURRENT_LIST_DIR}/../..")
set(TARGET_RELEASE_DIR "${REPO_ROOT}/target/release")
set(DIST_DIR "${CMAKE_CURRENT_LIST_DIR}/dist/${CMAKE_SYSTEM_NAME}")

add_custom_target(go_dist ALL
    COMMAND ${CMAKE_COMMAND} -E chdir ${REPO_ROOT} ${CARGO_EXECUTABLE}
            build --release --manifest-path ${WRAPPER_FFI_DIR}/Cargo.toml
    COMMAND ${CMAKE_COMMAND}
            -DHEADER_FILE=${WRAPPER_FFI_DIR}/include/dianyaapi_ffi.h
            -DTARGET_RELEASE_DIR=${TARGET_RELEASE_DIR}
            -DDIST_DIR=${DIST_DIR}
            -P ${CMAKE_CURRENT_LIST_DIR}/cmake/copy_artifacts.cmake
    COMMAND ${CMAKE_COMMAND} -E chdir ${CMAKE_CURRENT_LIST_DIR} ${GO_EXECUTABLE} build ./...
    COMMAND ${CMAKE_COMMAND} -E echo "Go bindings exported to ${DIST_DIR}"
    COMMENT "Building Rust FFI and Go bindings"
)

