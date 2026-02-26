cmake_minimum_required(VERSION 3.13)
cmake_policy(SET CMP0076 NEW)

project("test_native" VERSION 0.1.0 LANGUAGES C)

# SIDL Compilations
add_custom_command(
    OUTPUT "${CMAKE_BINARY_DIR}/byte_stream.h" "${CMAKE_BINARY_DIR}/byte_stream.c"
    COMMAND
        "${CMAKE_SOURCE_DIR}/../../../build/pkgroot/opt/homebrew/opt/folisdk/bin/sidlc"
            "${CMAKE_SOURCE_DIR}/../../../build/pkgroot/opt/homebrew/opt/folisdk/share/sidl/interfaces/byte_stream.sidl"
            "--header=${CMAKE_BINARY_DIR}/byte_stream.h"
            "--user-src=${CMAKE_BINARY_DIR}/byte_stream.c"
    DEPENDS
        "${CMAKE_SOURCE_DIR}/../../../build/pkgroot/opt/homebrew/opt/folisdk/share/sidl/interfaces/byte_stream.sidl"
)

# Target Configurations
add_executable(test_native main.c ${CMAKE_BINARY_DIR}/byte_stream.c)

# Compile Options
target_compile_features(test_native PUBLIC c_std_99)
target_compile_options(test_native PUBLIC 
    $<$<COMPILE_LANGUAGE:C>:
        -Werror
        -Wall
        -Wno-unused-function
        -Wno-unused-variable
        -Wno-unused-but-set-variable
        -pedantic
        -pedantic-errors
    >
)
target_link_options(test_native PRIVATE "-Wl,--gc-sections")

target_include_directories(test_native PRIVATE "${CMAKE_SOURCE_DIR}/include")
target_include_directories(test_native PRIVATE "${CMAKE_SOURCE_DIR}/../../../libstrata/include")
target_include_directories(test_native PRIVATE "${CMAKE_BINARY_DIR}")
