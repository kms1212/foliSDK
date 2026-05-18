cmake_minimum_required(VERSION 3.13)
cmake_policy(SET CMP0076 NEW)

project("test_native" VERSION 0.1.0 LANGUAGES C)

include(UseSIDLC)

# SIDL Compilations
sidlc_compile(
    OUTPUT_DIR "${CMAKE_CURRENT_BINARY_DIR}/sidl"
    SIFS_VAR SIDL_SIFS
    FILES "${SIDLC_INTERFACE_DIRECTORY}/byte_stream.sidl"
)
sidlc_generate(
    CLIENT
    HEADER_DIR "${CMAKE_CURRENT_BINARY_DIR}/sidl"
    SRCS_VAR SIDL_SRCS
    HDRS_VAR SIDL_HDRS
    SIFS ${SIDL_SIFS}
)

# Target Configurations
add_executable(test_native main.c ${SIDL_SRCS})

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

target_include_directories(test_native PRIVATE "${CMAKE_SOURCE_DIR}/include")
target_include_directories(test_native PRIVATE "${CMAKE_SOURCE_DIR}/../../../libstrata/include")
target_include_directories(test_native PRIVATE "${CMAKE_BINARY_DIR}")
