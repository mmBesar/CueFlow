{
  description = "CueFlow - native Markdown teleprompter";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs = { self, nixpkgs }:
    let
      systems = [ "x86_64-linux" "aarch64-linux" ];
      forAllSystems = nixpkgs.lib.genAttrs systems;

      pkgsFor = system: import nixpkgs { inherit system; };

      packageFor = system:
        let
          pkgs = pkgsFor system;
          buildCommit = if self ? rev then self.rev else if self ? dirtyRev then self.dirtyRev else "unknown";
        in pkgs.stdenv.mkDerivation {
          pname = "cueflow";
          version = "0.1.0";
          src = self;

          nativeBuildInputs = with pkgs; [
            cmake
            ninja
            pkg-config
            qt6.wrapQtAppsHook
          ];

          buildInputs = with pkgs.qt6; [
            qtbase
            qtdeclarative
            qtshadertools
          ];

          cmakeFlags = [
            "-DCMAKE_BUILD_TYPE=Release"
            "-DCUEFLOW_BUILD_APP=ON"
            "-DCUEFLOW_DEPLOY_QT_RUNTIME=OFF"
            "-DBUILD_TESTING=ON"
            "-DCUEFLOW_BUILD_COMMIT=${buildCommit}"
          ];

          doCheck = true;

          meta = {
            description = "Native Markdown teleprompter with Qt Quick";
            mainProgram = "cueflow";
            platforms = [ "x86_64-linux" "aarch64-linux" ];
          };
        };
    in {
      packages = forAllSystems (system: {
        default = packageFor system;
        cueflow = packageFor system;
      });

      apps = forAllSystems (system: {
        default = {
          type = "app";
          program = "${packageFor system}/bin/cueflow";
        };
      });

      devShells = forAllSystems (system:
        let pkgs = pkgsFor system;
        in {
          default = pkgs.mkShell {
            nativeBuildInputs = with pkgs; [
              cmake
              ninja
              pkg-config
              qt6.wrapQtAppsHook
            ];
            buildInputs = with pkgs.qt6; [ qtbase qtdeclarative qtshadertools ];
          };
        });
    };
}
