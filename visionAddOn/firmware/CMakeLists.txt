cmake_minimum_required(VERSION 3.22)

#
# This file is generated only once,
# and is not re-generated if converter is called multiple times.
#
# User is free to modify the file as much as necessary
#

# Setup compiler settings
set(CMAKE_C_STANDARD 11)
set(CMAKE_C_STANDARD_REQUIRED ON)
set(CMAKE_C_EXTENSIONS ON)

set(CMAKE_CXX_STANDARD 17)

# Define the build type
if(NOT CMAKE_BUILD_TYPE)
    set(CMAKE_BUILD_TYPE "Debug")
endif()

# Set the project name
set(CMAKE_PROJECT_NAME visionAddOn)

# Include toolchain file
include("cmake/gcc-arm-none-eabi.cmake")

# Enable compile command to ease indexing with e.g. clangd
set(CMAKE_EXPORT_COMPILE_COMMANDS TRUE)

# Enable CMake support for ASM, C and C++ languages
enable_language(C CXX ASM)

# Core project settings
project(${CMAKE_PROJECT_NAME})
message("Build type: " ${CMAKE_BUILD_TYPE})

# Create an executable object type
add_executable(${CMAKE_PROJECT_NAME}) # ${CMAKE_SOURCE_DIR/Core/Src/main.cpp})

# Add STM32CubeMX generated sources
add_subdirectory(cmake/stm32cubemx)

# Link directories setup
target_link_directories(${CMAKE_PROJECT_NAME} PRIVATE
    # Add user defined library search paths
)

# Add sources to executable
target_sources(${CMAKE_PROJECT_NAME} PRIVATE
    App/AppBuilder.cpp
    App/as4c16m16msa/sdram.c
    App/blob/BlobReceiver.cpp
    App/blob/ExternalInterruptHandler.cpp
    App/blob/UartInterruptHandler.cpp
    App/camera/Ov5640.cpp
    App/camera/Ov9281.cpp
    App/command/CommandPacket.cpp
    App/command/CommandHandler.cpp
    App/fpgaCommander/FpgaCommander.cpp
    App/frameTransfer/FrameTransfer.cpp
    App/network/NetworkManager.cpp
    App/network/NetworkStats.cpp
    App/network/NetworkTypes.cpp
    App/utils/allocator.c
    App/utils/assert.c
    App/utils/mutex/Mutex.cpp
    App/utils/pool/BufferPool.cpp
    App/utils/pool/CyclicPool.cpp
    App/utils/Log.cpp    
    App/storage/At24c02d.cpp
)

# Add include paths
target_include_directories(${CMAKE_PROJECT_NAME} PRIVATE
    App/
    App/as4c16m16msa
    App/blob
    App/camera
    App/command
    App/utils
    App/service
)

# Linker wrap option for malloc
target_link_options(${CMAKE_PROJECT_NAME} PRIVATE
    -Wl,--wrap,malloc
    -Wl,--wrap,cmalloc
    -Wl,--wrap,realloc
    -Wl,--wrap,free
)

# based on https://stackoverflow.com/questions/51727566/how-to-make-git-commit-hash-available-in-c-code-without-needless-recompiling
# Get the current working branch
execute_process(
    COMMAND git rev-parse --abbrev-ref HEAD
    WORKING_DIRECTORY ${CMAKE_SOURCE_DIR}
    OUTPUT_VARIABLE GIT_BRANCH
    OUTPUT_STRIP_TRAILING_WHITESPACE)

# Get the latest commit hash
execute_process(
    COMMAND git rev-parse HEAD
    WORKING_DIRECTORY ${CMAKE_SOURCE_DIR}
    OUTPUT_VARIABLE GIT_COMMIT_HASH
    OUTPUT_STRIP_TRAILING_WHITESPACE)


# Add project symbols (macros)
target_compile_definitions(${CMAKE_PROJECT_NAME} PRIVATE
    "-DGIT_COMMIT_HASH=\"${GIT_COMMIT_HASH}\""
)

# Treat all warnings as errors
target_compile_options(${CMAKE_PROJECT_NAME} PRIVATE
    -Wall -Wextra -Werror
)

file(GLOB_RECURSE DRIVER_SOURCE_FILES Drivers/*.c)
set_source_files_properties(${DRIVER_SOURCE_FILES} PROPERTIES COMPILE_FLAGS -Wno-unused-parameter)

# Add linked libraries
target_link_libraries(${CMAKE_PROJECT_NAME}
    stm32cubemx
    # Add user defined libraries
)
