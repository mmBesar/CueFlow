# NixOS development and running CueFlow

The generic Linux CI archive uses Qt's deployment script to copy Qt libraries
and QML imports next to the executable. That bundle is not a native NixOS
package and may still depend on system libraries that are not exposed in the
usual FHS paths (for example, `libxkbcommon.so.0`). Do not try to fix that by
copying random libraries into the bundle.

The GitHub Actions workflow also builds a precompiled NixOS-native package and
exports the full store closure in a commit-specific `cueflow-nixos-x86_64-<commit SHA>` artifact. The artifact also contains `build-info.txt` with the source commit, `qml/Main.qml` SHA-256, store path, and executable SHA-256. This lets
you run the CI build without compiling CueFlow locally. Download and extract
that artifact, then from the extracted directory run:

```sh
gzip -dc cueflow-nixos-x86_64.store.gz | nix-store --import
cat build-info.txt
out="$(cat store-path.txt)"
"$out/bin/cueflow"
```

The import adds the prebuilt application and its Qt/runtime dependencies to
`/nix/store`. The archive is for `x86_64-linux`; it is not a generic Linux tarball.

For local development/building from the source tree, run `nix run` from the
repository root.

To open a development environment and build manually:

```sh
nix develop
cmake -S . -B build -G Ninja \
  -DCMAKE_BUILD_TYPE=Debug \
  -DCUEFLOW_DEPLOY_QT_RUNTIME=OFF \
  -DBUILD_TESTING=ON
cmake --build build
ctest --test-dir build --output-on-failure
./build/cueflow
```

The first invocation resolves `nixpkgs` and may create `flake.lock`; commit that
lock file in the project if a fully pinned dependency set is desired. The Nix
package deliberately disables the copy-based Qt deployment step and runs with
the Qt libraries and QML imports provided by Nixpkgs.

The downloadable generic Linux tarball is still not intended to be a NixOS
native package. Use the newest `cueflow-nixos-x86_64-<commit SHA>` Actions artifact when you want a
prebuilt binary without running a local build. Its commit-specific name prevents
confusing an older NixOS build with a newer Android APK. When launched from a
terminal, CueFlow prints `CueFlow build commit: ...`; compare that value with
`source_commit` in `build-info.txt`.
