# GitHub-first development

CueFlow's CI is designed so that source can be pushed to GitHub and all compilation, tests, Qt downloads, and packaging happen on GitHub-hosted runners. A local C++/Qt toolchain is not required for ordinary verification.

## Jobs

The workflow deliberately uses **separately named jobs**, not a matrix, so each architecture/build appears as its own job in the GitHub Actions run:

- `Core tests — Linux amd64`
- `Core tests — Linux arm64`
- `Qt desktop build — Linux amd64`
- `Qt desktop build — Linux arm64`
- `Android APK — arm64-v8a`
- `Legacy Android APK — Android 6+ (32-bit ARM)`

RISC-V is temporarily excluded while we get the mainstream builds stable. It can be reintroduced later as a separate native RISE job.

## Why Qt is installed as visible commands

The workflow does not use `jurplel/install-qt-action` for Qt installation. That action groups internal commands and can leave the useful `aqtinstall` output tucked inside collapsed log groups. Here, Python installation, `aqtinstall` setup, repository metadata checks, and Qt package downloads are separate named workflow steps. The `aqt` command output is therefore ordinary step output, and any metadata/download/extraction exception should be visible directly in the failed step log.

The workflow pins released `aqtinstall==3.3.0` and `py7zr==1.1.4` instead of installing a moving development branch. The two Linux desktop jobs use Qt 6.8.3; Android uses Qt 6.12.0 because that release officially supports Android 16 and 16 KB page sizes. The host and target are intentionally distinct:

- Linux desktop amd64: host `linux`, target `desktop`, repository architecture ID `linux_gcc_64`; the installed Qt prefix is still under `gcc_64/`.
- Linux desktop arm64: host `linux_arm64`, target `desktop`, architecture `linux_gcc_arm64`.
- Android arm64: host `all_os`, target `android`, architecture `android_arm64_v8a` (Qt 6.7+ Android repository layout); JDK 21 and NDK `27.2.12479018`.

Qt Quick, Qt Declarative, Quick Controls, and the shader tools are supplied by the base Qt package installation for this configuration. The workflow does not pass these package/archive names to `--modules`. Both Linux desktop jobs install `libgl1-mesa-dev`, so Qt CMake can resolve `WrapOpenGL` (the runtime `libgl1` package alone does not provide the development headers and linker metadata). The Android job pins JDK 21 and Android NDK `27.2.12479018` for Qt 6.12.0. It packages a debug-signed arm64-v8a test APK and verifies its signature, 16 KB ZIP alignment, and 16 KB ELF LOAD-segment alignment before upload. On Android failure, the workflow uploads a diagnostic artifact with the pip/aqt version, metadata checks, Qt install output, CMake output, and build logs.

## Find normal step logs

1. Open the repository's **Actions** tab.
2. Select the latest **CueFlow CI** workflow run.
3. The run summary should list the jobs above individually.
4. Click the exact failed job; its named steps include **Install system dependencies**, **Install aqtinstall and archive support**, the architecture checks, the relevant Qt download step, and the later CMake/build/test steps.
5. Click/expand the failed step to see its command output. For the Qt download step, the `python -m aqt install-qt ...` output is no longer nested in `install-qt-action`'s internal log groups. On failed Qt/Android jobs, CI also uploads a `*-failure-diagnostics` artifact containing captured installer/build output and any generated CMake logs.

The PR **Checks** summary/annotation panel is not the full step log. If the summary only says “This job failed”, use the Actions run and select the named job and failed step.

## Artifact outputs

A successful workflow uploads these seven-day development artifacts:

- `cueflow-linux-amd64`
- `cueflow-linux-arm64`
- `cueflow-android-arm64-debug` — modern Qt 6.12 / Android 9+ / arm64-v8a.
- `cueflow-android6-armv7-legacy-debug` — Qt 5.15.2 / Android 6-compatible / armeabi-v7a; separate package ID.
- `cueflow-nixos-x86_64`

The Linux `.tar.gz` contains a Qt-deployed application tree; it is not an AppImage and still expects compatible host system libraries plus a graphical session. In particular, a host may need `libxkbcommon.so.0` (`libxkbcommon0` on Debian/Ubuntu; `libxkbcommon` on Fedora/Arch). On NixOS, this tarball is not a drop-in portable package because it depends on the host's dynamic-library environment. The Android artifact is a debug-signed test APK (not the project’s permanent release-signing identity) and needs real-device testing. The NixOS artifact contains an exported Nix store closure; import it with the steps in `docs/NIXOS.md`.

## Known limits

Workflow YAML and commands can be inspected locally, but only GitHub Actions can confirm that these particular Qt archive URLs, tool downloads, and platform toolchains work at run time. If a Qt job still fails, retain the complete output from **Check Qt repository architectures** and the relevant Qt download step; that output identifies whether the failure is a repository-query, download, or extraction problem.

CI does not replace real-device acceptance testing for Arabic/English BiDi, smooth live scrolling, remote pairing, display power management, and Android lifecycle behavior.


## Qt installation notes

For Linux amd64, use the Qt repository architecture identifier `linux_gcc_64`. In the current repository metadata, using `gcc_64` can make aqt find the extension feeds (`qtwebengine`, `qtpdf`) but fail to match the base `qt_base` package. The installed Qt prefix is still expected under `gcc_64/`, so the workflow discovers the prefix from `lib/cmake/Qt6/Qt6Config.cmake` and validates the required component config files. The Qt CMake checks also require OpenGL development files, provided by Ubuntu’s `libgl1-mesa-dev` package.

The Android job installs matching Qt 6.12.0 Linux host tools separately from the Android arm64-v8a Qt package, and passes the discovered host prefix as `QT_HOST_PATH` during CMake configuration. `QT_ANDROID_DEPLOYMENT_TYPE=Debug` selects a sideloadable debug-signed test package even though the native C++ compile uses Release optimization. The APK verification step prevents unsigned or non-16-KB-compatible test artifacts from being uploaded.


## NixOS artifact

The `NixOS native package — x86_64-linux` job builds the Qt application as a Nix derivation and exports the complete runtime store closure. This is intentionally separate from the generic Linux deployment tarball, whose dependencies can be invisible to the NixOS dynamic loader. Download the `cueflow-nixos-x86_64` artifact, extract it, and follow `docs/NIXOS.md` to import the closure into `/nix/store` and launch the prebuilt binary without compiling on the local machine.


## Legacy Android target

Android 6 is not supported by the current Qt 6.12 build (the modern artifact requires Android 9/API 28). The dedicated `android-legacy-armv7` job compiles the same QML/C++ source with Qt 5.15.2 and produces an `armeabi-v7a` debug APK with a separate application ID. The job deliberately uses JDK 17 for `setup-android` and SDK package installation because current Android command-line tools require JDK 17+, then switches to JDK 8 for Qt 5.15's older Gradle template. Because that Qt line is older, treat the artifact as a compatibility build for a trusted local device—not as the preferred build for modern phones. The job must pass before the artifact should be installed. Before qmake, the job copies the version-matched template from `$QT_LEGACY_ROOT/src/android/templates` and sets both `AndroidManifest.xml`'s package and Gradle's `applicationId` to `org.mmbesar.cueflow.legacy`; Qt 5.15/qmake ignores the project's earlier `ANDROID_PACKAGE_NAME` assignment. The build runs `make apk_install_target` to stage the native app library and resources into `android-build`, then invokes `androiddeployqt`. Calling `androiddeployqt` before staging triggers the missing `lib<target>_armeabi-v7a.so` error.

### Android 6 white-screen compatibility

The Qt 5.15.2 job creates a generated copy of `qml/Main.qml` with explicit Qt 5 module import versions. Qt 6 allows versionless imports; Qt 5 requires version numbers. The qrc used by `android-legacy/CueFlow.pro` loads that generated file. The job stores the imports in `diagnostics/qt5-qml-compatibility.log`, and the native executable logs failed QML component creation to logcat.
