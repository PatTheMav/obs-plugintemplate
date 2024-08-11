# OBS Plugin Template

## Introduction

The plugin template is meant to be used as a starting point for OBS Studio plugin development. It includes:

* Boilerplate plugin source code
* A CMake project file
* GitHub Actions workflows and repository actions

## QuickStart Guide

### Build Environment

| Platform  | Tool   |
|-----------|--------|
| Windows   | Visal Studio 17 2022 |
| macOS     | XCode 16.0 |
| Windows, macOS  | CMake 3.30.5 |
| Ubuntu 24.04 | CMake 3.28.3 |
| Ubuntu 24.04 | `ninja-build` |
| Ubuntu 24.04 | `pkg-config`
| Ubuntu 24.04 | `build-essential` |

### Build Steps

* Configure `buildspec.json` to contain your plugin metadata and - if necessary - update dependency information
* **Ubuntu only**: Have build dependencies installed:
    * `obs-studio`[^1]
    * `libgles2-mesa-dev`
    * `qt6-base-dev`, `libqt6svg6-dev`, and `qt6-base-private-dev`[^2]

* Run `cmake` to configure, build, and package the plugin (elements in square brackets are optional):
    * Configure: `cmake --preset <windows-x64|macos|ubuntu-x86_64>`
        * `[-DENABLE_QT=ON]`[^2]
        * `[-DENABLE_FRONTEND_API=ON]`[^3]
        * `[-DENABLE_CCACHE=ON]`[^4]
    * Build: `cmake --build --preset <windows-x64|macos|ubuntu-x86_64>`
        * `[--config <Release|RelWithDebInfo|Debug>]`[^5]
    * Install: `cmake --install <build_x64|build_macos|build_ubuntu>`
        * `[--prefix <desired installation location]`
    * Package: `cmake --build --preset ubuntu-x86_64 --target package` (_Ubuntu only_)

[^1]: Requires `sudo add-apt-repository --yes ppa:obsproject/obs-studio` to be run first to ensure ppa package is installed
[^2]: Only if the plugin provides its own Qt-based widgets or dialogs
[^3]: Only if the plugin interacts with the OBS Studio frontend via its frontend API
[^4]: Can be enabled to speed up local builds if necessary, refer to Ccache documentation about possible caveats
[^5]: By default `RelWithDebInfo` is used, CI will also use `Release` to generate release builds.

### Package Steps

#### Windows

* Generate installer executable with InnoSetup:
```PowerShell
iscc <Path-To-Checkout>/build_<ARCHITECTURE>/installer-Windows.generated.iss /O"<Path-To-Checkout>/release" /F"<Your-Plugin-Name>-Installer"
```
* Generate ZIP archive:
```PowerShell
Compress-Archive -Path <Path-To-Checkout>/release/RelWithDebInfo -CompressionLevel Optimal -DestinationPath <Path-To-Checkout>/release/<Your-Plugin-Name>.zip
```

#### macOS

* Codesign package:
```Bash
productsign --sign "<Your-Developer-ID-Installer-Cert-Name>" "<Path-To-Checkout>/release/RelWithDebInfo/<Your-Plugin-Name>.pkg"
```
* Notarize package following [Apple's instructions](https://developer.apple.com/documentation/security/customizing-the-notarization-workflow#Upload-your-app-to-the-notarization-service)
* Distribute generated package in `<Path-To-Checkout>/release/RelWithDebInfo/<Your-Plugin-Name>.pkg`

#### Ubuntu
* Generate an Ubuntu-style `deb` package:
```Bash
cmake --prefix ubuntu-x86_64 --target package
```
* Generate compressed tar archive
```Bash
cd <Path-To-Checkout>/release/RelWithDebInfo
XZ_OPT=-T0 tar -cJf <Path-To-Checkout>/release/<Your-Plugin-Name>.tar.xz lib share
```

## Detailed Setup

The plugin project is set up using the included `buildspec.json` file. The following fields should be customized for an actual plugin:

* `name`: The plugin name
* `version`: The plugin version
* `author`: Actual name or nickname of the plugin's author
* `website`: URL of a website associated with the plugin
* `email`: Contact email address associated with the plugin
* `uuids`
    * `windowsApp`: Unique (**!**) identifier for the Windows plugin installer

These values are read and processed automatically by the CMake build scripts, so no further adjustments in other files are needed.

### Platform Configuration

Platform-specific settings are set up in the `platformConfig` section of the buildspec file:

* `bundleId`: macOS bundle identifier for the plugin. Should be unique and follow reverse domain name notation.

### Set Up Build Dependencies

Just like OBS Studio itself, plugins need to be built using dependencies available either via the `obs-deps` repository (Windows and macOS) or via a distribution's package system (Ubuntu).

#### Choose An OBS Studio Version

By default the plugin template specifies the most current official OBS Studio version in the `buildspec.json` file, which makes most sense for plugins at the start of development. As far as updating the targeted OBS Studio version is concerned, a few things need to be considered:

* Plugins targeting _older_ versions of OBS Studio should _generally_ also work in newer versions, with the exception of breaking changes to specific APIs which would also be explicitly called out in release notes
* Plugins targeting the _latest_ version of OBS Studio might not work in older versions because the internal data structures used by `libobs` might not be compatible
* Users are encouraged to always update to the most recent version of OBS Studio available within a reasonable time after release - plugin authors have to choose for themselves if they'd rather keep up with OBS Studio releases or stay with an older version as their baseline (which might of course preclude the plugin from using functionality introduced in a newer version)

On Ubuntu, the version used for development might be decided by the specific version available via a distribution's package management system, so OBS Studio compatibility for plugins might be determined by those versions instead.

#### Windows and macOS

Windows and macOS dependency downloads are configured in the `buildspec.json` file:

* `dependencies`:
    * `obs-studio`: Version of OBS Studio to build plugin with (needed for `libobs` and `obs-frontend-api`)
    * `prebuilt`: Prebuilt OBS Studio dependencies
    * `qt6`: Prebuilt version of Qt6 as used by OBS Studio
* `tools`: Contains additional build tools used by CI (Optional)

The values should be kept in sync with OBS Studio releases and the `buildspec.json` file in use by the main project to ensure that the plugin is developed and built in sync with its target environment.

To update a dependency, change the `version` and associated `hashes` entries to match the new version. The used hash algorithm is `sha256`.

#### Ubuntu

Ubuntu dependencies need to be resolved using the package management tools appropriate for the local distribution. As an example, building on Ubuntu requires the following packages to be installed:

* Build System Dependencies:
    * `cmake`
    * `ninja-build`
    * `pkg-config`
* Build Dependencies:
    * `build-essential`
    * `obs-studio` - **Important:** Needs to be installed via the `ppa` package
* Qt6 Dependencies (if custom Qt widgets or dialogs are provided by the plugin):
    * `qt6-base-dev`
    * `libqt6svg6-dev`
    * `qt6-base-private-dev`

## Build System Configuration

To create a build configuration, `cmake` needs to be installed on the system. The plugin template supports CMake presets using the `CMakePresets.json` file and ships with default presets:

* `macos`
    * Universal architecture (supports Intel-based CPUs as Apple Silicon)
    * Defaults to macOS deployment target `11.0`
* `macos-ci`
    * Inherits from `macos`
    * Enables compile warnings as error
* `windows-x64`
    * Windows 64-bit architecture
    * Defaults to Visual Studio 17 2022
    * Defaults to Windows SDK version `10.0.22621`
* `windows-ci-x64`
    * Inherits from `windows-x64`
    * Enables compile warnings as error
* `ubuntu-x86_64`
    * Ubuntu x86_64 architecture
    * Defaults to Ninja as build tool
* `ubuntu-ci-x86_64`
    * Inherits from `ubuntu-x86_64`
    * Enables compile warnings as error

Presets can either be specified on the command line (`cmake --preset <PRESET>`) or via the associated select field in the CMake Windows GUI. Only presets appropriate for the current build host are available for selection.

Additional build system options are available to developers:

* `ENABLE_CCACHE`: Enables support for compilation speed-ups via ccache (disabled by default on macOS and Ubuntu for local builds)
* `ENABLE_FRONTEND_API`: Adds OBS Frontend API support for interactions with OBS Studio frontend functionality (disabled by default)
* `ENABLE_QT`: Adds Qt6 support for custom user interface elements (disabled by default)
* `CODESIGN_IDENTITY`: Name of the Apple Developer certificate that should be used for code signing
* `CODESIGN_TEAM`: Apple Developer team ID that should be used for code signing

## Creating Distributable Packages

#### Windows
By default, an InnoSetup script is generated by the build system and placed in the `build-<ARCHITECTURE>` sub-directory of the project named `installer-Windows.generated.iss` (with <ARCHITECTURE> being limited to just `x64` for the time being). This script file can be use with InnoSetup's `iscc` compiler to generate an installer executable:

```PowerShell
iscc <Path-To-Checkout>/build_<ARCHITECTURE>/installer-Windows.generated.iss /O"<Path-To-Checkout>/release" /F"<Your-Plugin-Name>-Installer"
```

To create a simple archive of your plugin, simply compress the contents of the chosen configuration subdirectory (e.g. `RelWithDebInfo`) inside the checkout root's `release` subdirectory with an archiving program of your choice[^6]:

```PowerShell
Compress-Archive -Path <Path-To-Checkout>/release/RelWithDebInfo -CompressionLevel Optimal -DestinationPath <Path-To-Checkout>/release/<Your-Plugin-Name>.zip
```

[^6]: Be careful to clean up the `release` directory contents after packaging your plugin to avoid re-packaging already existing packages on consecutive runs of these commands.

#### macOS

By default, the build system will automatically create a distributable package installer named `<Your-Plugin-Name>.pkg` in a subdirectory with the name of the chosen build configuration (e.g. `RelWithDebInfo`) inside the checkout root's `release` subdirectory.

For proper distribution, this package needs to be signed with a "Developer ID Installer" certificate (see below for more detailed information about signing information):

```Bash
productsign --sign "<Your-Developer-ID-Installer-Cert-Name>" "<Path-To-Checkout>/release/RelWithDebInfo/<Your-Plugin-Name>.pkg"
```

Finally, the package should also be notarized, for which [Apple provides documentation](https://developer.apple.com/documentation/security/customizing-the-notarization-workflow#Upload-your-app-to-the-notarization-service).

#### Ubuntu

CMake can be invoked to generate Ubuntu-compatible `deb` and `ddeb` packages directly, which will be put into the checkout root's `release` subdirectory:
```Bash
cmake --prefix ubuntu-x86_64 --target package
```

Alternatively, a simple compressed tar archive can be generated by simply archiving the entire contents of a directory specific to the chosen build configuration (e.g. `RelWithDebInfo` inside that same directory:
```Bash
cd <Path-To-Checkout>/release/RelWithDebInfo
XZ_OPT=-T0 tar -cJf <Path-To-Checkout>/release/<Your-Plugin-Name>.tar.xz lib share
```

Be mindful of the install prefix used for configuring the project (on Ubuntu this should be `/usr/lib/x86_64-linux-gnu` for x86_64 builds), as this becomes the required installation directory for the plugin.

## GitHub Actions & CI

Default GitHub Actions workflows are available for the following repository actions:

* `push`: Run for commits or tags pushed to `master` or `main` branches.
* `pr-pull`: Run when a Pull Request has been pushed or synchronized.
* `dispatch`: Run when triggered by the workflow dispatch in GitHub's user interface.
* `build-project`: Builds the actual project and is triggered by other workflows.
* `check-format`: Checks CMake and plugin source code formatting and is triggered by other workflows.

The workflows make use of GitHub repository actions (contained in `.github/actions`) and build scripts (contained in `.github/scripts`) which are not needed for local development, but might need to be adjusted if additional/different steps are required to build the plugin.

### Retrieving build artifacts

Successful builds on GitHub Actions will produce build artifacts that can be downloaded for testing. These artifacts are commonly simple archives and will not contain package installers or installation programs.

### Building a Release

To create a release, an appropriately named tag needs to be pushed to the `main`/`master` branch using semantic versioning (e.g., `12.3.4`, `23.4.5-beta2`). A draft release will be created on the associated repository with generated installer packages or installation programs attached as release artifacts.

## Signing and Notarizing on macOS

Plugins released for macOS should be codesigned and notarized with a valid Apple Developer ID for best user experience. To set this up, the private and personal key of a **paid Apple Developer ID** need to be downloaded from the Apple Developer portal:

* On your Apple Developer dashboard, go to "Certificates, IDs & Profiles" and create two signing certificates:
    * One of the "Developer ID Application" type. It will be used to sign the plugin's binaries
    * One of the "Developer ID Installer" type. It will be used to sign the plugin's installer

The developer certificate will usually carry a name similar in form to

`Developer ID Application: <FIRSTNAME> <LASTNAME> (<LETTERS_AND_NUMBERS>)`

This entire string should be specified as `CODESIGN_IDENTITY`, the `LETTERS_AND_NUMBERS` part as `CODESIGN_TEAM` to CMake to set up codesigning properly.

### GitHub Actions Set Up

To use code signing on GitHub Actions, the certificate and associated information need to be set up as _repository secrets_ in the GitHub repository's settings.

* First, the locally stored developer certificate needs to be exported from the macOS keychain:
    * Using the Keychain app on macOS, export these your certificates (Application and Installer) public _and_ private keys into a single .p12 file **protected with a strong password**
    * Encode the .p12 file into its base64 representation by running `base64 <NAME_OF_YOUR_P12_FILE>`
* Next, the certificate data and the password used to export it need to be set up as repository secrets:
    * `MACOS_SIGNING_APPLICATION_IDENTITY`: Name of the "Developer ID Application" signing certificate
    * `MACOS_SIGNING_INSTALLER_IDENTITY`: Name of "Developer ID Installer" signing certificate
    * `MACOS_SIGNING_CERT`: The base64 encoded `.p12` file
    * `MACOS_SIGNING_CERT_PASSWORD`: Password used to generate the .p12 certificate
* To also enable notarization on GitHub Action runners, the following repository secrets are required:
    * `MACOS_NOTARIZATION_USERNAME`: Your Apple Developer account's _Apple ID_
    * `MACOS_NOTARIZATION_PASSWORD`: Your Apple Developer account's _generated app password_
