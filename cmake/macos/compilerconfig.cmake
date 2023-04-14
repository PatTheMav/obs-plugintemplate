# CMake macOS compiler configuration module

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

# Add default C and C++ compiler options if Xcode generator is not used
if(NOT XCODE)
  set(_obs_c_options
      # cmake-format: sortable
      -fno-strict-aliasing
      -Wbool-conversion
      -Wcomma
      -Wconstant-conversion
      -Wdeprecated-declarations
      -Wempty-body
      -Wenum-conversion
      -Werror
      -Werror=block-capture-autoreleasing
      -Werror=return-type
      -Wextra
      -Wformat
      -Wformat-security
      -Wfour-char-constants
      -Winfinite-recursion
      -Wint-conversion
      -Wnewline-eof
      -Wno-conversion
      -Wno-float-conversion
      -Wno-implicit-fallthrough
      -Wno-missing-braces
      -Wno-missing-field-initializers
      -Wno-missing-prototypes
      -Wno-semicolon-before-method-body
      -Wno-shadow
      -Wno-sign-conversion
      -Wno-trigraphs
      -Wno-unknown-pragmas
      -Wno-unused-function
      -Wno-unused-label
      -Wnon-literal-null-conversion
      -Wobjc-literal-conversion
      -Wparentheses
      -Wpointer-sign
      -Wquoted-include-in-framework-header
      -Wshorten-64-to-32
      -Wsign-compare
      -Wstrict-prototypes
      -Wswitch
      -Wuninitialized
      -Wunreachable-code
      -Wunused-parameter
      -Wunused-value
      -Wunused-variable
      -Wvla)

  set(_obs_cxx_options
      # cmake-format: sortable
      -Warc-repeated-use-of-weak
      -Wconversion
      -Wdeprecated-implementations
      -Wduplicate-method-match
      -Wfloat-conversion
      -Wfour-char-constants
      -Wimplicit-retain-self
      -Winvalid-offsetof
      -Wmove
      -Wno-arc-maybe-repeated-use-of-weak
      -Wno-c++11-extensions
      -Wno-exit-time-destructors
      -Wno-implicit-atomic-properties
      -Wno-non-virtual-dtor
      -Wno-objc-interface-ivars
      -Wno-overloaded-virtual
      -Wno-selector
      -Wno-strict-selector-match
      -Wprotocol
      -Wrange-loop-analysis
      -Wshadow
      -Wundeclared-selector)

  # Enable stripping of dead symbols when not building for Debug configuration
  set(_release_configs RelWithDebInfo Release MinSizeRel)
  if(CMAKE_BUILD_TYPE IN_LIST _release_configs)
    target_link_options(${CMAKE_PROJECT_NAME} PRIVATE LINKER:-dead_strip)
  endif()

  target_compile_options(
    ${CMAKE_PROJECT_NAME} PRIVATE "$<$<COMPILE_LANGUAGE:C>:${_obs_c_options}>"
                                  "$<$<COMPILE_LANGUAGE:CXX>:${_obs_c_options} ${_obs_cxx_options}>")

  option(ENABLE_COMPILER_TRACE "Enable clang time-trace (requires Ninja)" OFF)
  mark_as_advanced(ENABLE_COMPILER_TRACE)

  # Add time trace option to compiler, if enabled.
  if(ENABLE_COMPILER_TRACE AND CMAKE_GENERATOR STREQUAL "Ninja")
    target_compile_options(${CMAKE_PROJECT_NAME} PRIVATE $<$<COMPILE_LANGUAGE:C>:-ftime-trace>
                                                         $<$<COMPILE_LANGUAGE:CXX>:-ftime-trace>)
  else()
    set(ENABLE_COMPILER_TRACE
        OFF
        CACHE STRING "Enable clang time-trace (requires Ninja)" FORCE)
  endif()

  # Enable color diagnostics for AppleClang
  set(CMAKE_COLOR_DIAGNOSTICS ON)
endif()

target_compile_definitions(${CMAKE_PROJECT_NAME} PRIVATE $<$<CONFIG:DEBUG>:DEBUG> $<$<CONFIG:DEBUG>:_DEBUG>)
