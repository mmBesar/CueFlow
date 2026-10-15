<p align="center">
  <img src="assets/icons/cueflow-icon.png" alt="CueFlow app icon" width="112" height="112">
</p>

# CueFlow — native Markdown teleprompter

CueFlow is a native-first Markdown teleprompter for Linux and Android, with local display and LAN remote-control modes in the same app. Version **0.1.0** is prepared as the first public release; after configuring the Android release-signing secrets described in [docs/RELEASING.md](docs/RELEASING.md), pushing the matching `v0.1.0` tag runs the release pipeline and creates a draft GitHub Release for final testing and publication.

## NixOS

For local development, a Nix flake provides the Qt build environment (`nix develop`, then see [`docs/NIXOS.md`](docs/NIXOS.md)). For users who do not want to build locally, the GitHub Actions workflow also exports a prebuilt Nix store closure as a commit-specific `cueflow-nixos-x86_64-<commit SHA>` artifact. Each NixOS artifact includes `build-info.txt` with the exact source commit and QML checksum.

## Goals

- One application that can be either **Display** or **Remote**.
- Native Linux desktop builds for `amd64` and `arm64`; a modern Android `arm64-v8a` APK plus a separate Qt 5.15.2 `armeabi-v7a` legacy APK for Android 6-era devices. RISC-V is temporarily out of CI while the core builds are stabilized.
- Markdown scripts and per-block automatic paragraph direction for Arabic/English BiDi text.
- Time-based scrolling in rendered pixels per second, not one-pixel timer increments; playback uses a 16 ms cadence and the frame timer sleeps while idle. Markdown BiDi updates only touch blocks when a direction format actually changes, avoiding repeated format-notification work.
- A live position slider, small pixel nudges, pause/resume while seeking, speed/font/text-width controls, reset, and fullscreen.
- Direct LAN connection: the display app temporarily hosts a local TCP session. No Docker, persistent server, cloud service, browser, or separate server process is required.
- Local settings and scripts persisted with `QSettings`.

## Current status

CueFlow is an early-stage native teleprompter app built with Qt Quick. GitHub Actions runs core unit tests, builds Linux desktop versions for x86_64 and aarch64, creates architecture-specific AppImages, and builds two Android targets: modern Qt 6 / arm64-v8a and legacy Qt 5.15.2 / armeabi-v7a for older devices. RISC-V is temporarily disabled while the supported builds are stabilized. CI builds and device testing are deliberately treated separately: the modern Android build still needs broad real-device acceptance testing, while the Android 6 legacy app has been confirmed by a user on an actual older phone.

The interface uses a custom CueFlow icon in the app header and native window, plus the Linux and Android launcher packages. The desktop display uses a right-side control dock on wide windows and a compact transport/tuning bar on narrow windows; the remote desktop keeps controls visible alongside the script editor instead of automatically scrolling the page down to the editor. Android maintains its separate touch-first layout. The UI includes Arabic/English Markdown with per-block BiDi handling, all four Catppuccin flavors and 26 palette accents, fullscreen floating controls, independent display/remote modes, four-digit LAN pairing PINs with a cooldown after repeated failures, and a screen-on request while Android is foregrounded. On Android and narrow screens the tuning sliders collapse behind a Tune action; the editor uses the full remaining screen space. On wide desktops, playback/position and reading adjustments live in a compact right-hand control dock beside the reading viewport; on narrower desktop windows, a two-row transport bar keeps the viewport dominant and tuning controls expandable. Play/Pause, Reset, and Remote remain visibly labeled. Android keeps its own larger touch targets. Desktop keyboard controls work in either role: Space toggles play/pause, Up/Down move the reading position, and Left/Right decrease/increase speed in 10 px/s steps. These shortcuts stay out of text-entry fields and focused sliders. Android fullscreen supports single-tap play/pause. The display remains the authoritative playback clock so remote clients do not drift against a different viewport range.

The `.github/workflows/ci.yml` workflow publishes short-lived development artifacts on normal CI runs. A version tag (`vMAJOR.MINOR.PATCH`) triggers a separate release-assembly job that prepares installable Linux bundles plus AppImages for x86_64 and aarch64, signs both Android APKs using a configured release keystore, generates SHA-256 checksums, and creates a **draft GitHub Release** for review. See [docs/RELEASING.md](docs/RELEASING.md) before creating a release tag and [the v0.1.0 release notes](docs/releases/v0.1.0.md). AppImages are the easiest Linux option to try, but are not fully independent of the host: the graphics/display stack, FUSE or extract-and-run support, and a sufficiently compatible glibc remain host concerns. The tarball is kept as an installable fallback; for NixOS use the separate NixOS artifact/guide.

The first pairing flow is deliberately manual: start a session on the display, then enter one of the displayed LAN addresses, port `47773`, and the four-digit PIN on the remote. The PIN remains stable until hosting is stopped; five failed pairing attempts trigger a 30-second cooldown. QR pairing, service discovery, and TLS remain planned follow-up work. On Android, CueFlow requests that the screen stay awake while the app is foregrounded. Keep the prototype on a trusted LAN; the initial TCP transport is not encrypted and must not be exposed to the public Internet.

## Architecture

- `src/ScrollModel.h` — dependency-free scroll model and units. Progress is normalized; speed is in rendered pixels/second. The elapsed-time step is capped to avoid a resume/suspend jump.
- `src/SessionController.*` — Qt state, local persistence, LAN hosting/remote connection, JSON-lines control messages, session snapshots, and per-Markdown-block BiDi direction.
- `qml/Main.qml` — shared Qt Quick UI for display and remote modes, with the four Catppuccin flavors and all 26 named palette colors available as accents.
- `tests/scroll_model_test.cpp` — unit tests for frame-rate independence, precise nudges, clamping, and playback-end behavior.

The display device is authoritative for playback. The remote sends intent (toggle, seek, nudge, speed, font size, width, replace script); the display broadcasts current state. Position is synchronized as a normalized fraction of the current scrollable range, while speed is physically meaningful in pixels/second. During a position drag, playback pauses and resumes afterward only if it had been playing before the drag.

## Android version support

- **Modern APK:** Qt 6.12, `arm64-v8a`, minimum Android 9 (API 28), target Android 16 (API 36). This is the recommended build for current phones.
- **Legacy APK:** Qt 5.15.2, 32-bit `armeabi-v7a`, minimum Android 5/API 21 (so Android 6/API 23 is within the stated Qt 5.15 support range), target API 28. Its separate package ID lets it coexist with the modern app. It is intended for old phones and does not replace the modern build. The Qt 5.15 line is older and should not be the default for new installations.

The legacy APK is only validated if the dedicated GitHub Actions job succeeds and it is then tested on the actual Android 6 device. Android 6 phones that lack support for 32-bit ARM apps cannot use this `armeabi-v7a` package. The legacy job copies Qt 5.15's own Android package template, explicitly sets both the manifest package and Gradle `applicationId` to `org.mmbesar.cueflow.legacy`, then runs `make apk_install_target` to stage the native binary and resources before invoking `androiddeployqt`. Before qmake, CI generates a Qt 5.15-compatible `android-legacy/generated/Main.qml` with explicit QML import versions, because the shared source uses Qt 6's versionless import syntax.

## Requirements

- Qt 6.5 or newer with `Core`, `Gui`, `Network`, `Qml`, `Quick`, `QuickControls2`, and Qt Quick Controls' Material style for the main app.
- CMake 3.21+, a C++20 compiler, and Ninja or Make.
- For Android packaging: Qt for Android plus the Android SDK/NDK and a compatible JDK/Gradle toolchain for the chosen Qt release.

## GitHub-first development

After this project is pushed to GitHub, every push and pull request will run `.github/workflows/ci.yml`. You do not need a local C++ compiler or Qt installation to verify a change: open the repository's **Actions** tab to inspect build and test results. Successful Qt builds attach short-lived, downloadable Linux tarball and AppImage test artifacts for x86_64 and aarch64. The AppImages bundle Qt/QML resources and most app-side libraries, but are not totally independent of the host: a compatible glibc, graphics drivers/display stack, and supported AppImage execution mode are still needed. The CI workflow builds a debug-signed Android arm64-v8a test APK; it is not a release signing identity. A separate NixOS job builds a Nix-native package and exports its complete store closure so it can be imported and run on NixOS without compiling locally. Version tags also assemble a draft user-facing GitHub Release; see [the release guide](docs/RELEASING.md) for Android signing secrets and the publish checklist.

The downloadable Linux tarballs contain Qt-deployed runtime files, an `AppRun` launcher, the CueFlow icon, and per-user `install.sh`/`uninstall.sh` scripts. Install from an extracted bundle with `./install.sh`; no sudo is needed. Alternatively, download the matching `CueFlow-Linux-x86_64-*.AppImage` or `CueFlow-Linux-aarch64-*.AppImage`, mark it executable if needed, then run it. AppImages can still depend on the host glibc, graphics/display stack, and AppImage runtime support; test older distributions before assuming compatibility. On NixOS, use the dedicated `cueflow-nixos-x86_64` Actions artifact or build the flake; neither generic Linux package is a replacement for the NixOS artifact.

The scroll model can be tested without Qt by configuring the core-only build:

```bash
cmake -S . -B build-core -G Ninja -DCUEFLOW_BUILD_APP=OFF -DBUILD_TESTING=ON
cmake --build build-core
ctest --test-dir build-core --output-on-failure
```

To run the standalone convenience script, provide a C++20 compiler as `c++` (or set `CXX` to its command name). This local step is optional when using GitHub Actions.

## Build the desktop application locally

Only needed when developing interactively outside GitHub-hosted runners. Requires Qt 6.5+ and the development tools listed below.

```bash
cmake -S . -B build -G Ninja -DCMAKE_BUILD_TYPE=Release
cmake --build build
ctest --test-dir build --output-on-failure
./build/cueflow
```

## User test checklist before calling this usable

1. Arabic-only, English-only, and mixed Arabic/English paragraphs with punctuation, numbers, code, URLs, Markdown headings, lists, block quotes, and tables.
2. Font-size changes during playback must not jump to a distant point.
3. Use Up/Down to move the reading position by 40 rendered pixels per press; Left/Right should change speed by 10 px/s, clamped to 0–600 px/s. Test locally and from a remote, in both Linux-display/Android-remote and Android-display/Linux-remote roles.
4. Drag the remote position slider while playing; the display should track continuously and resume after release.
5. Test both role directions: Linux display + Android remote, then Android display + Linux remote.
6. Test disconnect/reconnect, oversized script rejection, unavailable port, and wrong PIN.
7. Test on Wayland and X11, then build/run on ARM64 Linux. Reintroduce RISC-V testing once the main CI paths are reliable.

## License

MIT — see `LICENSE`.


**CI note:** Qt builds install the Qt Declarative (`Qml`, `Quick`, `QuickControls2`) and Shader Tools modules. Linux Qt roots are discovered from `Qt6Config.cmake` rather than hard-coded from an architecture alias. Android uses a matching Linux host Qt install via `QT_HOST_PATH`. RISC-V CI is currently disabled.

## Android 6 legacy build

The Qt 5.15.2 legacy target uses versioned QML imports. Run `python3 scripts/prepare-qt5-legacy-qml.py` before qmake; it generates an ignored compatibility copy from `qml/Main.qml`.

### Diagnosing Android 6 startup

The legacy build logs QML load/creation errors with the `CueFlow QML:` prefix. If startup still fails on the old phone, connect it with ADB and capture `adb logcat` immediately after launching CueFlow. The application now exits if its QML root object cannot be created instead of showing a misleading blank window.
