#!/usr/bin/env zsh

builtin emulate -L zsh
setopt EXTENDED_GLOB
setopt PUSHD_SILENT
setopt ERR_EXIT
setopt ERR_RETURN
setopt NO_UNSET
setopt PIPE_FAIL
setopt NO_AUTO_PUSHD
setopt NO_PUSHD_IGNORE_DUPS
setopt FUNCTION_ARGZERO

## Enable for script debugging
# setopt WARN_CREATE_GLOBAL
# setopt WARN_NESTED_VAR
# setopt XTRACE

autoload -Uz is-at-least && if ! is-at-least 5.2; then
  print -u2 -PR "${CI:+::error::}%F{1}${funcstack[1]##*/}:%f Running on Zsh version %B${ZSH_VERSION}%b, but Zsh %B5.2%b is the minimum supported version. Upgrade Zsh to fix this issue."
  exit 1
fi

TRAPEXIT() {
  local return_value=$?

  if (( ${+CI} )) {
    unset NSUnbufferedIO
  }

  return ${return_value}
}

TRAPZERR() {
  print -u2 -PR "${CI:+::error::}%F{1}    ✖︎ script execution error%f"
  print -PR -e "
    Callstack:
    ${(j:\n     :)funcfiletrace}
  "
  log_group
  exit 2
}

package() {
  if (( ! ${+SCRIPT_HOME} )) typeset -g SCRIPT_HOME=${ZSH_ARGZERO:A:h}
  local host_os=${${(s:-:)ZSH_ARGZERO:t:r}[2]}
  local project_root=${SCRIPT_HOME:A:h:h}
  local buildspec_file="${project_root}/buildspec.json"

  fpath=("${SCRIPT_HOME}/utils.zsh" ${fpath})
  autoload -Uz set_loglevel log_info log_error log_output check_${host_os}

  local -i _verbosity=1
  local -r _version='2.0.0'
  local -r -a _valid_targets=(
    macos-universal
    linux-x86_64
    linux-aarch64
  )
  local target

  local -r _usage="
Usage: %B${functrace[1]%:*}%b <option> [<options>]

%BOptions%b:

%F{yellow} Package configuration options%f
 -----------------------------------------------------------------------------
  %B-t | --target%b                     Specify target
  %B-s | --codesign%b                   Enable codesigning (macOS only)
  %B-n | --notarize%b                   Enable notarization (macOS only)
  %B-p | --package%b                    Create package installer (macOS only)

%F{yellow} Output options%f
 -----------------------------------------------------------------------------
  %B-q | --quiet%b                      Quiet (error output only)
  %B-v | --verbose%b                    Verbose (more detailed output)
  %B--debug%b                           Debug (very detailed and added output)

%F{yellow} General options%f
 -----------------------------------------------------------------------------
  %B-h | --help%b                       Print this usage help
  %B-V | --version%b                    Print script version information"

  local -a args
  while (( # )) {
    case ${1} {
      -t|--target)
        if (( # == 1 )) || [[ ${2:0:1} == '-' ]] {
          log_error "Missing value for option %B${1}%b"
          log_output ${_usage}
          exit 2
        }
        ;;
    }
    case ${1} {
      --)
        shift
        args+=($@)
        break
        ;;
      -t|--target)
        if (( ! ${_valid_targets[(Ie)${2}]} )) {
          log_error "Invalid value %B${2}%b for option %B${1}%b"
          log_output ${_usage}
          exit 2
        }
        target=${2}
        shift 2
        ;;
      -s|--codesign) typeset -g CODESIGN=1; shift ;;
      -n|--notarize) typeset -g NOTARIZE=1; typeset -g CODESIGN=1; shift ;;
      -p|--package) typeset -g PACKAGE=1; shift ;;
      -q|--quiet) (( _verbosity -= 1 )) || true; shift ;;
      -v|--verbose) (( _verbosity += 1 )); shift ;;
      -h|--help) log_output ${_usage}; exit 0 ;;
      -V|--version) print -Pr "${_version}"; exit 0 ;;
      --debug) _verbosity=3; shift ;;
      *) log_error "Unknown option: %B${1}%b"; log_output ${_usage}; exit 2 ;;
    }
  }

  : "${target:="${host_os}-${CPUTYPE}"}"

  set -- ${(@)args}
  set_loglevel ${_verbosity}

  check_${host_os}

  local product_name
  local product_version
  read -r product_name product_version <<< \
    "$(jq -r '. | {name, version} | join(" ")' ${project_root}/buildspec.json)"

  local build_config
  if (( ${+CI} )) {
    case ${GITHUB_EVENT_NAME} {
      pull_request) build_config='RelWithDebInfo' ;;
      push)
        if [[ ${GITHUB_REF_NAME} =~ [0-9]+.[0-9]+.[0-9]+(-(rc|beta).+)? ]] {
          build_config='Release'
        } else {
          build_config='RelWithDebInfo'
        }
        ;;
    }
  } else {
    build_config='Release'
  }

  if [[ ${host_os} == 'macos' ]] {
    autoload -Uz check_packages read_codesign read_codesign_installer read_codesign_pass

    local output_name="${product_name}-${product_version}-${host_os}-universal"

    if [[ ! -d ${project_root}/release/${build_config}/${product_name}.plugin ]] {
      log_error 'No release artifact found. Run the build script or the CMake install procedure first.'
      return 2
    }

    if (( ${+PACKAGE} )) {
      if [[ ! -f ${project_root}/build_macos/installer-macos.generated.pkgproj ]] {
        log_error 'Packages project file not found. Run the build script or the CMake build and install procedures first.'
        return 2
      }

      check_packages

      log_group "Packaging ${product_name}..."
      pushd ${project_root}
      packagesbuild \
        --build-folder ${project_root}/release/${build_config} \
        ${project_root}/build_macos/installer-macos.generated.pkgproj

      if (( ${+CODESIGN} )) {
        read_codesign_installer
        productsign \
          --sign "${CODESIGN_IDENT_INSTALLER}" \
          "${project_root}/release/${build_config}/${product_name}.pkg" \
          "${project_root}/release/${output_name}.pkg"

        rm "${project_root}/release/${build_config}/${product_name}.pkg"
      } else {
        mv "${project_root}/release/${build_config}/${product_name}.pkg" \
          "${project_root}/release/${output_name}.pkg"
      }

      if (( ${+CODESIGN} && ${+NOTARIZE} )) {
        if [[ ! -f "${project_root}/release/${output_name}.pkg" ]] {
          log_error "No package for notarization found."
          return 2
        }

        read_codesign_installer
        read_codesign_pass

        xcrun notarytool submit "${project_root}/release/${output_name}.pkg" \
          --keychain-profile "OBS-Codesign-Password" --wait

        local -i _status=0

        xcrun stapler staple "${project_root}/release/${output_name}.pkg" || _status=1

        if (( _status )) {
          log_error "Notarization failed - use 'xcrun notarytool log <Submission ID>' to check for errors.'"
          return 2
        }
      }
      popd
    } else {
      log_group "Archiving ${product_name}..."
      local _tarflags='cJf'
      if (( _loglevel > 1  || ${+CI} )) _tarflags="v${_tarflags}"

      pushd "${project_root}/release/${build_config}"
      XZ_OPT=-T0 tar "-${_tarflags}" "${project_root}/release/${output_name}.tar.xz" "${product_name}.plugin"
      popd
    }
    log_group
  } elif [[ ${host_os} == 'linux' ]] {
    local -a cmake_args=()
    if (( _loglevel > 1 )) cmake_args+=(--verbose)

    log_group "Creating source tarball for ${product_name}..."
    pushd ${project_root}
    cmake --build build_${target##*-} --config ${build_config} -t package_source ${cmake_args}
    popd

    if (( ${+PACKAGE} )) {
      log_group "Packaging ${product_name}..."
      pushd ${project_root}
      cmake --build build_${target##*-} --config ${build_config} -t package ${cmake_args}
      popd
    } else {
      log_group "Archiving ${product_name}..."
      local output_name="${product_name}-${product_version}-${target##*-}-linux-gnu"
      local _tarflags='cJf'
      if (( _loglevel > 1 || ${+CI} )) _tarflags="v${_tarflags}"

      pushd "${project_root}/release"
      XZ_OPT=-T0 tar "-${_tarflags}" "${project_root}/release/${output_name}.tar.xz" (lib|share)
      popd
    }
    log_group
  }
}

package ${@}
