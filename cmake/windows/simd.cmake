# CMake Windows SIMD module

# Enable openmp-simd when compiling for arm64
if(CMAKE_SYSTEM_PROCESSOR MATCHES "[aA]?[aA][rR]([mM]|[cC][hH])64")
  set(ARCH_SIMD_FLAGS -openmp:experimental)
  set(ARCH_SIMD_DEFINES SIMDE_ENABLE_OPENMP)
endif()
