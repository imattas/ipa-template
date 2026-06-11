# appcore — C++17 framework/library
#
# Build:
#   cmake -B build -DCMAKE_BUILD_TYPE=Release
#   cmake --build build
#   ctest --test-dir build --output-on-failure
#
# On Apple platforms this can also be configured as a real framework via
# `add_library(appcore SHARED ...)` + the FRAMEWORK target property; see the
# commented block at the bottom.

cmake_minimum_required(VERSION 3.20)
project(appcore VERSION 0.1.0 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

find_package(Threads REQUIRED)

add_library(appcore
    src/version.cpp
    src/event_bus.cpp
)
target_include_directories(appcore PUBLIC
    $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/include>
    $<INSTALL_INTERFACE:include>
)
target_link_libraries(appcore PUBLIC Threads::Threads)
target_compile_options(appcore PRIVATE -Wall -Wextra -Wpedantic)

enable_testing()
foreach(test_src test_event_bus test_result_queue)
    add_executable(${test_src} tests/${test_src}.cpp)
    target_link_libraries(${test_src} PRIVATE appcore)
    target_include_directories(${test_src} PRIVATE tests)
    add_test(NAME ${test_src} COMMAND ${test_src})
endforeach()

# --- Apple framework packaging (uncomment when targeting iOS/macOS) ---------
# set_target_properties(appcore PROPERTIES
#     FRAMEWORK TRUE
#     MACOSX_FRAMEWORK_IDENTIFIER com.example.appcore
#     VERSION ${PROJECT_VERSION}
#     PUBLIC_HEADER "include/appcore/version.hpp;include/appcore/result.hpp;include/appcore/event_bus.hpp;include/appcore/task_queue.hpp"
# )
