# CMake common compiler options module

# Enable language extension fallback to CMAKE_<LANG>_EXTENSIONS_DEFAULT
if(POLICY CMP0128)
  cmake_policy(SET CMP0128 NEW)
endif()

# Set symbols to be hidden by default for C and C++
set(CMAKE_CXX_VISIBILITY_PRESET hidden)
set(CMAKE_C_VISIBILITY_PRESET hidden)
set(CMAKE_VISIBILITY_INLINES_HIDDEN TRUE)
