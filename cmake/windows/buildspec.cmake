# CMake Windows build dependencies module

# cmake-format: off
# cmake-lint: disable=C0103
# cmake-lint: disable=E1126
# cmake-lint: disable=R0912
# cmake-lint: disable=R0915
# cmake-format: on

include(buildspec_common)

# _check_dependencies: Fetch and extract pre-built OBS build dependencies
function(_check_dependencies)
  file(READ "${CMAKE_CURRENT_SOURCE_DIR}/buildspec.json" buildspec)

  # cmake-format: off
  string(JSON dependency_data GET ${buildspec} dependencies)
  # cmake-format: on

  set(dependencies_dir "${CMAKE_CURRENT_SOURCE_DIR}/.deps")
  set(prebuilt_filename "windows-deps-VERSION-ARCH-REVISION.zip")
  set(prebuilt_destination "obs-deps-VERSION-ARCH")
  set(qt6_filename "windows-deps-qt6-VERSION-ARCH-REVISION.zip")
  set(qt6_destination "obs-deps-qt6-VERSION-ARCH")
  set(obs-studio_filename "VERSION.zip")
  set(obs-studio_destination "obs-studio-VERSION")

  set(arch ${CMAKE_GENERATOR_PLATFORM})

  foreach(dependency IN ITEMS prebuilt qt6 obs-studio)
    # cmake-format: off
    string(JSON data GET ${dependency_data} ${dependency})
    string(JSON version GET ${data} version)
    string(JSON hash GET ${data} hashes windows-${arch})
    string(JSON url GET ${data} baseUrl)
    string(JSON label GET ${data} label)
    string(JSON revision ERROR_VARIABLE error GET ${data} revision windows-${arch})
    # cmake-format: on

    message(STATUS "Setting up ${label} (${arch})")

    set(file "${${dependency}_filename}")
    set(destination "${${dependency}_destination}")
    string(REPLACE "VERSION" "${version}" file "${file}")
    string(REPLACE "VERSION" "${version}" destination "${destination}")
    string(REPLACE "ARCH" "${arch}" file "${file}")
    string(REPLACE "ARCH" "${arch}" destination "${destination}")
    if(revision)
      string(REPLACE "_REVISION" "_v${revision}" file "${file}")
      string(REPLACE "-REVISION" "-v${revision}" file "${file}")
    else()
      string(REPLACE "_REVISION" "" file "${file}")
      string(REPLACE "-REVISION" "" file "${file}")
    endif()

    set(skip FALSE)
    if(dependency STREQUAL prebuilt OR dependency STREQUAL qt6)
      _check_deps_version(${version})

      if(found)
        set(skip TRUE)
      endif()
    endif()

    if(skip)
      message(STATUS "Setting up ${label} (${arch}) - skipped")
      continue()
    endif()

    if(dependency STREQUAL obs-studio)
      set(url ${url}/${file})
    else()
      set(url ${url}/${version}/${file})
    endif()

    if(NOT EXISTS "${dependencies_dir}/${file}")
      message(STATUS "Downloading ${url}")
      file(
        DOWNLOAD "${url}" "${dependencies_dir}/${file}"
        STATUS download_status
        EXPECTED_HASH SHA256=${hash})

      list(GET download_status 0 error_code)
      list(GET download_status 1 error_message)
      if(error_code GREATER 0)
        message(STATUS "Downloading ${url} - Failure")
        message(FATAL_ERROR "Unable to download ${url}, failed with error: ${error_message}")
        file(REMOVE "${dependencies_dir}/${file}")
      else()
        message(STATUS "Downloading ${url} - done")
      endif()
    endif()

    if(NOT EXISTS "${dependencies_dir}/${destination}")
      file(MAKE_DIRECTORY "${dependencies_dir}/${destination}")
      if(dependency STREQUAL obs-studio)
        file(ARCHIVE_EXTRACT INPUT "${dependencies_dir}/${file}" DESTINATION "${dependencies_dir}")
      else()
        file(ARCHIVE_EXTRACT INPUT "${dependencies_dir}/${file}" DESTINATION "${dependencies_dir}/${destination}")
      endif()
    endif()

    if(dependency STREQUAL prebuilt)
      list(APPEND CMAKE_PREFIX_PATH "${dependencies_dir}/${destination}")
    elseif(dependency STREQUAL qt6)
      list(APPEND CMAKE_PREFIX_PATH "${dependencies_dir}/${destination}")
    elseif(dependency STREQUAL obs-studio)
      set(_obs_version ${version})
      set(_obs_destination "${destination}")
      list(APPEND CMAKE_PREFIX_PATH "${dependencies_dir}")
    endif()

    message(STATUS "Setting up ${label} - done")
  endforeach()

  list(REMOVE_DUPLICATES CMAKE_PREFIX_PATH)

  set(CMAKE_PREFIX_PATH
      ${CMAKE_PREFIX_PATH}
      CACHE PATH "CMake prefix search path" FORCE)

  _setup_obs_studio()
endfunction()

_check_dependencies()
