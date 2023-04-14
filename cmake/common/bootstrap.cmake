cmake_minimum_required(VERSION 3.16...3.26)

# Enable automatic PUSH and POP of policies to parent scope
if(POLICY CMP0011)
  cmake_policy(SET CMP0011 NEW)
endif()

# Prohibit in-source builds
if("${CMAKE_BINARY_DIR}" STREQUAL "${CMAKE_SOURCE_DIR}")
  message(FATAL_ERROR "In-source builds are not supported." "
      Specify a build directory via 'cmake -S <SOURCE DIRECTORY> -B <BUILD_DIRECTORY>' instead.")
endif()
file(REMOVE_RECURSE "${CMAKE_SOURCE_DIR}/CMakeCache.txt" "${CMAKE_SOURCE_DIR}/CMakeFiles")

# Use folders for source file organization with IDE generators (Visual Studio/Xcode)
set_property(GLOBAL PROPERTY USE_FOLDERS ON)

# Add common module directories to default search path
list(APPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_SOURCE_DIR}/cmake/common")

file(READ "${CMAKE_CURRENT_SOURCE_DIR}/buildspec.json" buildspec)

# cmake-format: off
string(JSON _name GET ${buildspec} name)
string(JSON _website GET ${buildspec} website)
string(JSON _author GET ${buildspec} author)
string(JSON _email GET ${buildspec} email)
string(JSON _version GET ${buildspec} version)
string(JSON _bundleId GET ${buildspec} platformConfig macos bundleId)
# cmake-format: on

set(PLUGIN_AUTHOR ${_author})
set(PLUGIN_WEBSITE ${_website})
set(PLUGIN_EMAIL ${_email})
set(PLUGIN_VERSION ${_version})
set(MACOS_BUNDLEID ${_bundleId})

include(buildnumber)
include(osconfig)

# Set C and C++ language standards to C17 and C++17
set(CMAKE_C_STANDARD 17)
set(CMAKE_C_STANDARD_REQUIRED TRUE)
set(CMAKE_C_EXTENSIONS FALSE)
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED TRUE)
set(CMAKE_CXX_EXTENSIONS FALSE)

# Allow selection of common build types via UI
if(NOT CMAKE_BUILD_TYPE)
  set(CMAKE_BUILD_TYPE
      "RelWithDebInfo"
      CACHE STRING "OBS build type [Release, RelWithDebInfo, Debug, MinSizeRel]" FORCE)
  set_property(CACHE CMAKE_BUILD_TYPE PROPERTY STRINGS Release RelWithDebInfo Debug MinSizeRel)
endif()

# Disable exports automatically going into the CMake package registry
set(CMAKE_EXPORT_PACKAGE_REGISTRY FALSE)
# Enable default inclusion of targets' source and binary directory
set(CMAKE_INCLUDE_CURRENT_DIR TRUE)
