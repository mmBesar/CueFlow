# CueFlow — native teleprompter (prototype)

CueFlow is a proposed native-first successor to PrompterNG. It is a new project scaffold, not a patch to the existing repository.

## NixOS

For local development, a Nix flake provides the Qt build environment (`nix develop`, then see [`docs/NIXOS.md`](docs/NIXOS.md)). For users who do not want to build locally, the GitHub Actions workflow also exports a prebuilt Nix store closure as the `cueflow-nixos-x86_64` artifact.

## Goals

- One application that can be either **Display** or **Remote**.
- Native Linux desktop builds for `amd64` and `arm64`; Android `arm64-v8a` is the first mobile target. RISC-V is temporarily out of CI while the core builds are stabilized.
- Markdown scripts and per-block automatic paragraph direction for Arabic/English BiDi text.
- Time-based scrolling in rendered pixels per second, not one-pixel timer increments; local playback ticks every 8 ms while running.
- A live position slider, small pixel nudges, pause/resume while seeking, speed/font/text-width controls, reset, and fullscreen.
- Direct LAN connection: the display app temporarily hosts a local TCP session. No Docker, persistent server, cloud service, browser, or separate server process is required.
- Local settings and scripts persisted with `QSettings`.

## Current status

This is an initial engineering prototype/scaffold. The included GitHub Actions workflow runs core unit tests on Linux amd64 and arm64, and builds/tests the Qt application on amd64 and arm64 plus an Android arm64-v8a APK. The workflow uses individually named jobs, with Qt installation commands split into normal workflow steps to make installer logs easier to inspect. RISC-V is temporarily disabled. The GUI is still a prototype: CI compilation is not a substitute for real-device tests of Arabic/English BiDi, live seeking, remote sessions, and screen-on lifecycle behavior. Android keeps the screen awake while CueFlow is foregrounded; the four Catppuccin flavors and all 26 named palette colors are available in Appearance settings, with compact 34px controls that auto-hide and return on touch/click. Local playback ticks at up to 125 Hz, while the display remains the sole playback clock so remote clients do not drift against a different viewport range. Successful Qt builds are staged with Qt's deployment tooling and attached to the workflow as downloadable Linux test bundles. These are for compatible Linux desktop systems, not yet universal AppImages or polished release packages.

The first pairing flow is deliberately manual: start a session on the display, then enter one of the displayed LAN addresses, port `47773`, and the six-digit PIN on the remote. In this prototype, that PIN remains valid until hosting is stopped; expiry, attempt throttling, QR pairing, service discovery, and TLS are planned follow-up work. On Android, CueFlow requests that the screen stay awake while the app is foregrounded. Keep the prototype on a trusted LAN; the initial TCP transport is not encrypted and must not be exposed to the public Internet.

## Architecture

- `src/ScrollModel.h` — dependency-free scroll model and units. Progress is normalized; speed is in rendered pixels/second. The elapsed-time step is capped to avoid a resume/suspend jump.
- `src/SessionController.*` — Qt state, local persistence, LAN hosting/remote connection, JSON-lines control messages, session snapshots, and per-Markdown-block BiDi direction.
- `qml/Main.qml` — shared Qt Quick UI for display and remote modes, with the four Catppuccin flavors and all 26 named palette colors available as accents.
- `tests/scroll_model_test.cpp` — unit tests for frame-rate independence, precise nudges, clamping, and playback-end behavior.

The display device is authoritative for playback. The remote sends intent (toggle, seek, nudge, speed, font size, width, replace script); the display broadcasts current state. Position is synchronized as a normalized fraction of the current scrollable range, while speed is physically meaningful in pixels/second. During a position drag, playback pauses and resumes afterward only if it had been playing before the drag.

## Requirements

- Qt 6.5 or newer with `Core`, `Gui`, `Network`, `Qml`, `Quick`, `QuickControls2`, and Qt Quick Controls' Material style.
- CMake 3.21+, a C++20 compiler, and Ninja or Make.
- For Android packaging: Qt for Android plus the Android SDK/NDK and a compatible JDK/Gradle toolchain for the chosen Qt release.

## GitHub-first development

After this project is pushed to GitHub, every push and pull request will run `.github/workflows/ci.yml`. You do not need a local C++ compiler or Qt installation to verify a change: open the repository's **Actions** tab to inspect build and test results. Successful Qt builds attach short-lived, downloadable Linux test bundles containing the application and its Qt/QML runtime. These are not universal AppImages; the host still needs compatible system libraries and a Linux graphical session. The CI workflow builds a debug-signed Android arm64-v8a test APK; it is not a release signing identity. A separate NixOS job builds a Nix-native package and exports its complete store closure so it can be imported and run on NixOS without compiling locally.

The downloadable Linux tarballs are Qt-deployed test bundles, not self-contained AppImages. They still need host runtime libraries for the window system and graphics stack. For example, startup can fail if `libxkbcommon.so.0` is unavailable. On NixOS, use the dedicated `cueflow-nixos-x86_64` Actions artifact; the generic Linux tarball is not a drop-in NixOS package.

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
3. Hold left/right nudges; position should move in small steps, never in percentage-sized leaps.
4. Drag the remote position slider while playing; the display should track continuously and resume after release.
5. Test both role directions: Linux display + Android remote, then Android display + Linux remote.
6. Test disconnect/reconnect, oversized script rejection, unavailable port, and wrong PIN.
7. Test on Wayland and X11, then build/run on ARM64 Linux. Reintroduce RISC-V testing once the main CI paths are reliable.

## License

MIT — see `LICENSE`.


**CI note:** Qt builds install the Qt Declarative (`Qml`, `Quick`, `QuickControls2`) and Shader Tools modules. Linux Qt roots are discovered from `Qt6Config.cmake` rather than hard-coded from an architecture alias. Android uses a matching Linux host Qt install via `QT_HOST_PATH`. RISC-V CI is currently disabled.
