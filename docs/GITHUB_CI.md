# GitHub-first development

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
3. Open the repository's **Actions** tab and inspect the `CueFlow CI` run. The first run is also the first end-to-end check of the Qt and Android build configuration; those jobs have not been run in this development workspace.

## What Actions checks

- `core-tests`: configure, compile, and run the playback model tests on native Linux amd64 and arm64.
- `riscv64-core`: cross-compile the dependency-free playback tests for RISC-V64 and run them under QEMU. This does **not** prove the full Qt GUI builds or runs on RISC-V64.
- `linux-app-build`: install Qt 6.8 LTS, build the app, run tests, and stage the application together with its Qt/QML runtime on native Linux amd64 and arm64 runners.
- `android-apk`: build an arm64-v8a APK using Qt for Android and upload it as a workflow artifact.

## Get a build

Open a successful workflow run and use its **Artifacts** section. The Linux artifacts are `cueflow-linux-amd64` and `cueflow-linux-arm64`; the Android artifact is `cueflow-android-arm64`. Artifacts expire after seven days and are meant for development testing, not as permanent releases. Download artifacts from the run; no local compilation is needed.

The Linux `.tar.gz` contains a Qt-deployed application tree. Extract it and launch `bin/cueflow` from the extracted directory. It still requires compatible system libraries and a working Linux graphical session; it is not an AppImage. The Android artifact is a development APK and needs real-device testing.

## What remains manual

CI compilation cannot verify the visual behavior of mixed Arabic/English BiDi text, precise live scrolling, rotation/power behavior, or remote control between real devices. Keep those as explicit acceptance tests. Android release signing, permanent GitHub Releases, a universal Linux AppImage, and a full RISC-V64 Qt build are not configured yet.
