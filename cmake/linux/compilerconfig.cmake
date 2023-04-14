# CMake Linux compiler configuration module

# Enable distinction between Clang and AppleClang
if(POLICY CMP0025)
  cmake_policy(SET CMP0025 NEW)
endif()

# Honor visibility presets for all target types (executable, shared, module, static)
if(POLICY CMP0063)
  cmake_policy(SET CMP0063 NEW)
endif()

include(ccache)
include(compiler_common)
include(simd)

target_compile_options(${CMAKE_PROJECT_NAME} PRIVATE -fno-strict-aliasing -Werror -Wall -Wformat-security -Wvla)

option(ENABLE_COMPILER_TRACE "Enable Clang time-trace (required Clang and Ninja)" OFF)
mark_as_advanced(ENABLE_COMPILER_TRACE)

if(ENABLE_COMPILER_TRACE AND CMAKE_GENERATOR STREQUAL "Ninja")
  target_compile_options(${CMAKE_PROJECT_NAME} PRIVATE $<$<COMPILE_LANG_AND_ID:C,Clang>:-ftime-trace>
                                                       $<$<COMPILE_LANG_AND_ID:CXX,Clang>:-ftime-trace>)
else()
  set(ENABLE_COMPILER_TRACE
      OFF
      CACHE STRING "Enable Clang time-trace (required Clang and Ninja)" FORCE)
endif()

if(CMAKE_VERSION VERSION_GREATER_EQUAL 3.24.0)
  set(CMAKE_COLOR_DIAGNOSTICS ON)
else()
  target_compile_options(${CMAKE_PROJECT_NAME} PRIVATE $<$<C_COMPILER_ID:Clang>:-fcolor-diagnostics>
                                                       $<$<CXX_COMPILER_ID:Clang>:-fcolor-diagnostics>)
endif()

if(CMAKE_CXX_COMPILER_ID STREQUAL "GNU" AND CMAKE_CXX_COMPILER_VERSION VERSION_EQUAL "12.1.0")
  target_compile_options(${CMAKE_PROJECT_NAME} PRIVATE -Wno-error=maybe-uninitialized)
endif()

target_compile_definitions(${CMAKE_PROJECT_NAME} PRIVATE $<$<CONFIG:DEBUG>:DEBUG> $<$<CONFIG:DEBUG>:_DEBUG>)
