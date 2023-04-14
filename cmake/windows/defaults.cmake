# CMake Windows defaults module

# Disable export function calls to populate package registry by default
if(POLICY CMP0090)
  cmake_policy(SET CMP0090 NEW)
endif()

# Enable find_package targets to become globally available targets
set(CMAKE_FIND_PACKAGE_TARGETS_GLOBAL TRUE)

include(buildspec)
