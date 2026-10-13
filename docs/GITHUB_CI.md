# GitHub-first development


## Qt installer note

The CI pins Qt to 6.8.3 so package selection is reproducible. For Qt 6.7 and newer, Android packages must use `host: all_os` with `target: android`; they are no longer resolved from `linux/android`. The current workflow also temporarily installs `aqtinstall` from its upstream Git repository to pick up fixes for Qt repository metadata parsing issues. This is a workaround, not a permanent dependency pin; remove `aqtsource` once the corresponding fix ships in a released `aqtinstall` version.

The Linux Qt installer failure should be diagnosed from the full **Install Qt** step log, not only the short Actions annotation. The workflow disables the Qt cache during this troubleshooting run so a stale cache cannot mask the result.

CueFlow is intended to be built and tested by GitHub Actions, so contributors do not need a local C++ or Qt toolchain just to validate changes.

## First push

1. Create a new GitHub repository named `CueFlow` (a public repository is recommended so standard GitHub-hosted Linux ARM64 runners are available for free). Do not initialize it with another README or license; this source tree already contains both.
2. Push this directory as the repository's first commit. From the project directory, after creating the empty repository:

   ```bash
   git init -b main
   git add .
   git commit -m "ci: add GitHub Actions builds"
   git remote add origin https://github.com/mmBesar/CueFlow.git
   git push -u origin main
   ```

   These commands only commit and push source; they do not compile anything locally. If the new repository has a different name or owner, change the remote URL accordingly.
3. Open the repository's **Actions** tab and inspect the `CueFlow CI` run. The first run is also the first end-to-end check of the Qt and Android build configuration; those jobs have not been run in this development workspace. The RISC-V job additionally requires the RISE Personal GitHub App to be installed on this repository.

## What Actions checks

- `core-tests`: configure, compile, and run the playback model tests on native Linux amd64 and arm64.
- `riscv64-core`: compile and run the dependency-free playback tests on **native RISC-V64 hardware** through the RISE RISC-V Runners GitHub App. Install the [RISE RISC-V Runners (Personal) app](https://github.com/apps/rise-risc-v-runners-personal) on this repository first. This validates the core on real hardware, but does **not** prove the full Qt GUI builds or runs on RISC-V64.
- `linux-app-build`: install Qt 6.8.3, build the app, run tests, and stage the application together with its Qt/QML runtime on native Linux amd64 and arm64 runners. It temporarily sources `aqtinstall` from upstream Git to pick up fixes for Qt repository metadata parsing, and selects the latest compatible `py7zr` 1.1 patch.
- `android-apk`: build an arm64-v8a APK using Qt for Android (`host: all_os`, `target: android`) and upload it as a workflow artifact. Qt 6.7+ Android packages use the `all_os` repository. The NDK version is pinned to 27.2.12479018.

## Get a build

Open a successful workflow run and use its **Artifacts** section. The Linux artifacts are `cueflow-linux-amd64` and `cueflow-linux-arm64`; the Android artifact is `cueflow-android-arm64`. Artifacts expire after seven days and are meant for development testing, not as permanent releases. Download artifacts from the run; no local compilation is needed.

The Linux `.tar.gz` contains a Qt-deployed application tree. Extract it and launch `bin/cueflow` from the extracted directory. It still requires compatible system libraries and a working Linux graphical session; it is not an AppImage. The Android artifact is a development APK and needs real-device testing.

## What remains manual

CI compilation cannot verify the visual behavior of mixed Arabic/English BiDi text, precise live scrolling, rotation/power behavior, or remote control between real devices. Keep those as explicit acceptance tests. Android release signing, permanent GitHub Releases, a universal Linux AppImage, and a full RISC-V64 Qt build are not configured yet.


## If a Qt installation job fails

Open the failed `Install Qt` or `Install Qt for Android` step and expand its complete log, not just the Actions annotations summary. The annotation only reports that the Python installer exited with status 1; the preceding `aqtinstall` output contains the actual reason (for example, missing package metadata, download failure, or archive extraction failure). For Qt 6.7+, the Android installer uses `host: all_os`; using `linux` makes version discovery fail because newer Android packages are published in the `all_os` repository. The desktop builds still use `linux` for amd64 and `linux_arm64` for arm64.

## RISE RISC-V runner status

The RISC-V job uses the exact official RISE label `runs-on: ubuntu-24.04-riscv`. Its first step prints `uname -a` and requires `uname -m` to be `riscv64`; the C++ build is native, without QEMU or a cross-compiler. `riscv64gc-unknown-linux-gnu` is a Rust target triple and is not needed by this C++/CMake job.

Install the [RISE RISC-V Runners (Personal) GitHub App](https://github.com/apps/rise-risc-v-runners-personal) on the personal account/repository that owns this project. Per the [official FAQ](https://riscv-runners.riseproject.dev/docs/faq.html), if the job is **Queued**, it can remain queued until a matching RISC-V node has capacity; the scheduler checks again every 15 seconds. If a workflow run was started before this native-runner job was committed, cancel that older run and start a new run on the latest commit: edits do not change jobs already created in an existing run.
