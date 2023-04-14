# Common build dependencies module

# _check_deps_version: Checks for obs-deps VERSION file in prefix paths
macro(_check_deps_version version)
  set(found FALSE)

  foreach(path IN LISTS CMAKE_PREFIX_PATH)
    if(EXISTS "${path}/share/obs-deps/VERSION")
      if(dependency STREQUAL qt6 AND NOT EXISTS "${path}/lib/cmake/Qt6/Qt6Config.cmake")
        set(found FALSE)
        continue()
      endif()

      file(READ "${path}/share/obs-deps/VERSION" _check_version)
      string(REPLACE "\n" "" _check_version "${_check_version}")
      string(REPLACE "-" "." _check_version "${_check_version}")
      string(REPLACE "-" "." version "${version}")

      if(_check_version VERSION_EQUAL version)
        set(found TRUE)
        break()
      elseif(_check_version VERSION_LESS version)
        message(AUTHOR_WARNING "Outdated ${label} version detected in ${path}: \n"
                               "Found ${_check_version}, require ${version}")
        list(REMOVE_ITEM CMAKE_PREFIX_PATH "${path}")
        list(APPEND CMAKE_PREFIX_PATH "${path}")
        continue()
      else()
        message(AUTHOR_WARNING "Future ${label} version detected in ${path}: \n"
                               "Found ${_check_version}, require ${version}")
        set(found TRUE)
        break()
      endif()
    endif()
  endforeach()
endmacro()

# _setup_obs_studio: Create obs-studio build project, then build libobs and obs-frontend-api
macro(_setup_obs_studio)
  if(NOT libobs_DIR)
    set(_is_fresh --fresh)
  endif()

  if(OS_WINDOWS)
    set(_cmake_generator "${CMAKE_GENERATOR}")
    set(_cmake_arch "-A ${arch}")
    set(_cmake_extra "-DCMAKE_SYSTEM_VERSION=${CMAKE_SYSTEM_VERSION} -DCMAKE_ENABLE_SCRIPTING=OFF")
    set(_cmake_version "2.0.0")
  elseif(OS_MACOS)
    set(_cmake_generator "Xcode")
    set(_cmake_arch "-DCMAKE_OSX_ARCHITECTURES:STRING='arm64;x86_64'")
    set(_cmake_extra "-DCMAKE_OSX_DEPLOYMENT_TARGET=${CMAKE_OSX_DEPLOYMENT_TARGET}")
    set(_cmake_version "3.0.0")
  endif()

  message(STATUS "Configure ${label} (${arch})")
  execute_process(
    COMMAND
      "${CMAKE_COMMAND}" -S "${dependencies_dir}/${_obs_destination}" -B
      "${dependencies_dir}/${_obs_destination}/build_${arch}" -G ${_cmake_generator} "${_cmake_arch}"
      -DOBS_CMAKE_VERSION:STRING=${_cmake_version} -DENABLE_PLUGINS:BOOL=OFF -DENABLE_UI:BOOL=OFF
      -DOBS_VERSION_OVERRIDE:STRING=${_obs_version} "-DCMAKE_PREFIX_PATH='${CMAKE_PREFIX_PATH}'" ${_is_fresh}
      ${_cmake_extra}
    RESULT_VARIABLE _process_result COMMAND_ERROR_IS_FATAL ANY
    OUTPUT_QUIET)
  message(STATUS "Configure ${label} (${arch}) - done")

  message(STATUS "Build ${label} (${arch})")
  execute_process(
    COMMAND "${CMAKE_COMMAND}" --build build_${arch} --target obs-frontend-api --config Debug --parallel
    WORKING_DIRECTORY "${dependencies_dir}/${_obs_destination}"
    RESULT_VARIABLE _process_result COMMAND_ERROR_IS_FATAL ANY
    OUTPUT_QUIET)
  message(STATUS "Build ${label} (${arch}) - done")

  message(STATUS "Install ${label} (${arch})")
  if(OS_WINDOWS)
    set(_cmake_extra "--component obs_libraries")
  else()
    set(_cmake_extra "")
  endif()
  execute_process(
    COMMAND "${CMAKE_COMMAND}" --install build_${arch} --component Development --config Debug --prefix
            "${dependencies_dir}" ${_cmake_extra}
    WORKING_DIRECTORY "${dependencies_dir}/${_obs_destination}"
    RESULT_VARIABLE _process_result COMMAND_ERROR_IS_FATAL ANY
    OUTPUT_QUIET)
  message(STATUS "Install ${label} (${arch}) - done")
endmacro()
