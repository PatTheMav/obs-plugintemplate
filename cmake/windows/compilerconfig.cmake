# CMake Windows compiler configuration module

# Honor visibility presets for all target types (executable, shared, module, static)
if(POLICY CMP0063)
  cmake_policy(SET CMP0063 NEW)
endif()

include(compiler_common)
include(simd)

# CMake 3.24 introduces a bug mistakenly interpreting MSVC as supporting the '-pthread' compiler flag
if(CMAKE_VERSION VERSION_EQUAL 3.24.0)
  set(THREADS_HAVE_PTHREAD_ARG FALSE)
endif()

message(DEBUG "Current Windows API version: ${CMAKE_VS_WINDOWS_TARGET_PLATFORM_VERSION}")
if(CMAKE_VS_WINDOWS_TARGET_PLATFORM_VERSION_MAXIMUM)
  message(DEBUG "Maximum Windows API version: ${CMAKE_VS_WINDOWS_TARGET_PLATFORM_VERSION_MAXIMUM}")
endif()

if(CMAKE_VS_WINDOWS_TARGET_PLATFORM_VERSION VERSION_LESS 10.0.20348)
  message(FATAL_ERROR "OBS required Windows 10 SDK version 10.0.20348.0 or more recent.\n"
                      "Please download and install the most recent Windows platform SDK.")
endif()

target_compile_options(${CMAKE_PROJECT_NAME} PRIVATE /MP /W3 /WX /utf-8)

target_compile_definitions(
  ${CMAKE_PROJECT_NAME} PRIVATE UNICODE _UNICODE _CRT_SECURE_NO_WARNINGS _CRT_NONSTDC_NO_WARNINGS
                                $<$<CONFIG:DEBUG>:DEBUG> $<$<CONFIG:DEBUG>:_DEBUG>)
target_link_options(
  ${CMAKE_PROJECT_NAME}
  PRIVATE
  /WX
  "$<$<NOT:$<CONFIG:Debug>>:/OPT:REF>"
  "$<$<CONFIG:Debug>:/INCREMENTAL:NO>"
  "$<$<CONFIG:RelWithDebInfo>:/INCREMENTAL:NO>"
  "$<$<CONFIG:RelWithDebInfo>:/OPT:ICF>")
