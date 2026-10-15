# CueFlow release process

CueFlow development CI artifacts are short-lived test builds. User-facing releases are created from version tags (`vMAJOR.MINOR.PATCH`) and appear as **draft GitHub Releases** so the assets can be reviewed and tested before publication.

## Platforms currently packaged

- Linux `x86_64` and `aarch64`: a standalone AppImage plus a Qt/QML tarball with `install.sh`/`uninstall.sh` for a per-user install. The tarball install does not require root privileges. AppImages bundle the Qt/QML runtime and most application-side libraries, but still depend on host glibc and the graphics/display stack; compatibility should be tested on older distributions. Keep the tarball as a fallback if an AppImage does not run on a host.
- Android modern: Qt 6, `arm64-v8a`, Android 9/API 28 and newer.
- Android legacy: Qt 5.15.2, `armeabi-v7a`, Android 5/API 21 and newer (including Android 6 devices, subject to device ABI support).
- NixOS: x86_64 exported Nix store closure with the matching store-path and build metadata. A normal Nix flake build also supports x86_64 and aarch64.

There are no Windows or macOS packages in the current build matrix, and the generic Linux bundle should not be used as the NixOS package.

## Android release signing (required before tagging)

The modern and legacy CI artifacts are deliberately **debug-signed test APKs**. Tag releases are re-signed with a stable release key so users can install updates without changing signing identity. Before creating a release tag, create a private Android signing keystore and configure these repository Actions secrets:

- `CUEFLOW_ANDROID_KEYSTORE_BASE64` — base64-encoded JKS/PKCS12 keystore bytes, on one line.
- `CUEFLOW_ANDROID_KEYSTORE_PASSWORD` — keystore password.
- `CUEFLOW_ANDROID_KEY_ALIAS` — private-key alias.
- `CUEFLOW_ANDROID_KEY_PASSWORD` — private-key password.

Example key creation (keep the resulting keystore and passwords backed up securely; never commit them):

```sh
keytool -genkeypair -v \
  -keystore cueflow-release.jks \
  -keyalg RSA -keysize 4096 -validity 10000 \
  -alias cueflow
base64 -w0 cueflow-release.jks > cueflow-release.jks.base64
```

Copy the base64 file's contents into the first secret. Do not put the keystore or passwords in repository files, issue comments, or workflow logs. The same key is used to sign both package IDs so future APK updates have a consistent signer. Losing the key may prevent users from installing signed updates over the existing release.

## Publishing a release

1. Update the project version in `CMakeLists.txt` and `flake.nix` together, and update user-facing release notes.
2. Confirm branch CI is green, particularly both Android jobs. Test the modern APK on a current phone and the legacy APK on a real Android 6-era device; CI compilation alone is not device acceptance.
3. Ensure all four Android signing secrets above are configured.
4. Commit the version change, then create and push a matching tag, for example `git tag -a v0.1.0 -m 'CueFlow 0.1.0' && git push origin v0.1.0`.
5. The workflow builds all current targets, packages AppImages for x86_64 and aarch64, signs and verifies the release APKs, generates SHA-256 checksums, and creates a **draft** GitHub Release. Inspect its assets and release notes, test the AppImages on both architectures (and preferably an older glibc-based distribution), test the tarball installers, test the APKs on real devices, then publish the draft manually.

A tag must match the `project(CueFlow VERSION ...)` value in `CMakeLists.txt`; this prevents accidentally publishing artifacts with inconsistent versions. Release assets include `SHA256SUMS` for integrity checking.
