cmake_minimum_required(VERSION 3.10)
project(DianyaAPI_FFI)

set(CMAKE_C_STANDARD 11)
set(CMAKE_C_STANDARD_REQUIRED ON)

# 设置默认构建类型为 Release
if(NOT CMAKE_BUILD_TYPE)
    set(CMAKE_BUILD_TYPE Release CACHE STRING "Build type" FORCE)
    set_property(CACHE CMAKE_BUILD_TYPE PROPERTY STRINGS "Debug" "Release")
endif()

# 根据构建类型设置 Rust 构建目录
if(CMAKE_BUILD_TYPE STREQUAL "Debug")
    set(RUST_BUILD_TYPE "debug")
    set(RUST_BUILD_FLAG "")
else()
    set(RUST_BUILD_TYPE "release")
    set(RUST_BUILD_FLAG "--release")
endif()

# 库文件路径
# 注意：由于是 Cargo workspace，构建产物在根目录的 target/ 下
get_filename_component(WORKSPACE_ROOT "${CMAKE_SOURCE_DIR}/.." ABSOLUTE)
set(LIB_DIR "${WORKSPACE_ROOT}/target/${RUST_BUILD_TYPE}")
set(INCLUDE_DIR "${CMAKE_SOURCE_DIR}/include")

# 根据操作系统设置库文件名
if(UNIX AND NOT APPLE)
    set(LIB_NAME "dianyaapi_ffi")
    set(LIB_FILE "${LIB_DIR}/lib${LIB_NAME}.so")
elseif(APPLE)
    set(LIB_NAME "dianyaapi_ffi")
    set(LIB_FILE "${LIB_DIR}/lib${LIB_NAME}.dylib")
elseif(WIN32)
    set(LIB_NAME "dianyaapi_ffi")
    set(LIB_FILE "${LIB_DIR}/${LIB_NAME}.dll")
endif()

# 查找 cargo 命令
find_program(CARGO cargo)
if(NOT CARGO)
    message(FATAL_ERROR "cargo not found! Please install Rust toolchain.")
endif()

# 设置 Cargo 工作目录
# 由于是 workspace，需要在根目录执行 cargo build
get_filename_component(WORKSPACE_ROOT "${CMAKE_SOURCE_DIR}/.." ABSOLUTE)
set(CARGO_WORKING_DIR "${WORKSPACE_ROOT}")

# 头文件路径（由 cargo build 通过 build.rs 生成）
set(HEADER_FILE "${INCLUDE_DIR}/dianyaapi_ffi.h")

# 构建 Rust 库的自定义目标（包括生成头文件）
# 需要在仓库根目录（dianyaapi-ffi）下构建，库文件会在 workspace 根目录的 target/ 下
add_custom_target(rust_lib
    COMMAND ${CARGO} build ${RUST_BUILD_FLAG} -p dianyaapi-ffi
    WORKING_DIRECTORY ${CARGO_WORKING_DIR}
    COMMENT "Building Rust library (${RUST_BUILD_TYPE})..."
    BYPRODUCTS ${LIB_FILE} ${HEADER_FILE}
)

# 包含目录
include_directories(${INCLUDE_DIR})

# 示例程序
add_executable(c_example examples/c/main.c)

# 依赖 Rust 库构建（会自动生成头文件）
add_dependencies(c_example rust_lib)

# 链接库
target_link_directories(c_example PRIVATE ${LIB_DIR})
target_link_libraries(c_example PRIVATE ${LIB_NAME})

# 设置运行时库路径（Linux/macOS）
if(UNIX)
    set_target_properties(c_example PROPERTIES
        INSTALL_RPATH "${LIB_DIR}"
        BUILD_WITH_INSTALL_RPATH TRUE
    )
endif()

# 安装规则（可选）
install(TARGETS c_example DESTINATION bin)
install(FILES ${LIB_FILE} DESTINATION lib)
install(FILES ${INCLUDE_DIR}/dianyaapi_ffi.h DESTINATION include)

# 使用说明
message(STATUS "")
message(STATUS "=== DianyaAPI FFI CMake Configuration ===")
message(STATUS "Build type: ${CMAKE_BUILD_TYPE}")
message(STATUS "Rust build type: ${RUST_BUILD_TYPE}")
message(STATUS "Library directory: ${LIB_DIR}")
message(STATUS "Include directory: ${INCLUDE_DIR}")
message(STATUS "Library file: ${LIB_FILE}")
message(STATUS "Cargo executable: ${CARGO}")
message(STATUS "")
message(STATUS "To build (Release):")
message(STATUS "  mkdir build && cd build")
message(STATUS "  cmake -DCMAKE_BUILD_TYPE=Release ..")
message(STATUS "  cmake --build .")
message(STATUS "")
message(STATUS "To build (Debug):")
message(STATUS "  mkdir build && cd build")
message(STATUS "  cmake -DCMAKE_BUILD_TYPE=Debug ..")
message(STATUS "  cmake --build .")
message(STATUS "")
message(STATUS "Note: Rust library will be built automatically during cmake --build")
message(STATUS "")
message(STATUS "To run:")
if(UNIX AND NOT APPLE)
    message(STATUS "  LD_LIBRARY_PATH=${LIB_DIR} ./c_example")
elseif(APPLE)
    message(STATUS "  DYLD_LIBRARY_PATH=${LIB_DIR} ./c_example")
elseif(WIN32)
    message(STATUS "  set PATH=%PATH%;${LIB_DIR} && c_example.exe")
endif()
message(STATUS "")

