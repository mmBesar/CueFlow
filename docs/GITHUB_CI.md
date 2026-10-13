# GitHub-first development

CueFlow's CI is designed so that source can be pushed to GitHub and all compilation, tests, Qt downloads, and packaging happen on GitHub-hosted runners. A local C++/Qt toolchain is not required for ordinary verification.

## Jobs

The workflow deliberately uses **five separately named jobs**, not a matrix, so each architecture/build appears as its own job in the GitHub Actions run:

- `Core tests — Linux amd64`
- `Core tests — Linux arm64`
- `Qt desktop build — Linux amd64`
- `Qt desktop build — Linux arm64`
- `Android APK — arm64-v8a`

RISC-V is temporarily excluded while we get the mainstream builds stable. It can be reintroduced later as a separate native RISE job.

## Why Qt is installed as visible commands

The workflow does not use `jurplel/install-qt-action` for Qt installation. That action groups internal commands and can leave the useful `aqtinstall` output tucked inside collapsed log groups. Here, Python installation, `aqtinstall` setup, repository metadata checks, and Qt package downloads are separate named workflow steps. The `aqt` command output is therefore ordinary step output, and any metadata/download/extraction exception should be visible directly in the failed step log.

The workflow pins released `aqtinstall==3.3.0` and `py7zr==1.1.4` instead of installing a moving development branch. Qt is pinned to 6.8.3 for reproducible package selection. The host and target are intentionally distinct:

- Linux desktop amd64: host `linux`, target `desktop`, architecture `linux_gcc_64` (Qt 6.7+ naming).
- Linux desktop arm64: host `linux_arm64`, target `desktop`, architecture `linux_gcc_arm64`.
- Android arm64: host `all_os`, target `android`, architecture `android_arm64_v8a` (Qt 6.7+ Android repository layout).

Qt Quick's declarative framework comes with the base Qt installation, so it is not requested as an add-on module. The workflow separately requests `qtshadertools`. The Android job pins JDK 17 and Android NDK `27.2.12479018`, which is supported for Qt 6.8, and packages an arm64-v8a APK. On Android failure, the workflow uploads a diagnostic artifact with the pip/aqt version, metadata checks, Qt install output, CMake output, and build logs.

## Find normal step logs

1. Open the repository's **Actions** tab.
2. Select the latest **CueFlow CI** workflow run.
3. The run summary should list the five jobs above individually.
4. Click the exact failed job; its named steps include **Install system dependencies**, **Install aqtinstall and archive support**, **Check Qt repository metadata**, **Download Qt 6.8.3 packages**, and the later CMake/build/test steps.
5. Click/expand the failed step to see its command output. For the Qt download step, the `python -m aqt install-qt ...` output is no longer nested in `install-qt-action`'s internal log groups. On failed Qt/Android jobs, CI also uploads a `*-failure-diagnostics` artifact containing captured installer/build output and any generated CMake logs.

The PR **Checks** summary/annotation panel is not the full step log. If the summary only says “This job failed”, use the Actions run and select the named job and failed step.

## Artifact outputs

A successful workflow uploads these seven-day development artifacts:

- `cueflow-linux-amd64`
- `cueflow-linux-arm64`
- `cueflow-android-arm64`

The Linux `.tar.gz` contains a Qt-deployed application tree; it is not an AppImage and still expects compatible host system libraries plus a graphical session. The Android APK is unsigned for release distribution and needs real-device testing.

## Known limits

Workflow YAML and commands can be inspected locally, but only GitHub Actions can confirm that these particular Qt archive URLs, tool downloads, and platform toolchains work at run time. If a Qt job still fails, retain the complete output from the **Check Qt repository architectures**, **Check Qt 6.8.3 add-on modules**, and **Download Qt 6.8.3 packages** steps; that output identifies whether the failure is a repository-query, download, or extraction problem.

CI does not replace real-device acceptance testing for Arabic/English BiDi, smooth live scrolling, remote pairing, display power management, and Android lifecycle behavior.
