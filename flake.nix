{
  description = "gitui (fork): blazing fast terminal-ui for git";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs =
    { self, nixpkgs }:
    let
      forAllSystems = nixpkgs.lib.genAttrs [
        "x86_64-linux"
        "aarch64-linux"
        "x86_64-darwin"
        "aarch64-darwin"
      ];
      version = (builtins.fromTOML (builtins.readFile ./Cargo.toml)).package.version;
      rev = self.shortRev or self.dirtyShortRev or "unknown";
    in
    {
      packages = forAllSystems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
          inherit (pkgs) lib stdenv;
        in
        {
          # mirrors nixpkgs' gitui derivation, built from this checkout
          gitui = pkgs.rustPlatform.buildRustPackage {
            pname = "gitui";
            inherit version;

            src = lib.cleanSource self;
            cargoLock.lockFile = ./Cargo.lock;

            nativeBuildInputs = with pkgs; [
              pkg-config
              cmake
            ];

            buildInputs = [
              pkgs.openssl
            ]
            ++ lib.optional stdenv.hostPlatform.isLinux pkgs.xclip
            ++ lib.optional stdenv.hostPlatform.isDarwin pkgs.libiconv;

            postPatch = ''
              # linker overrides for some targets break the build under nix
              rm .cargo/config.toml

              # build script shells out to git for the commit hash
              rm build.rs
              substituteInPlace Cargo.toml --replace-fail 'build = "build.rs"' ""
            '';

            env = {
              GITUI_BUILD_NAME = "${version}-fork (${rev})";
              # use system openssl via pkg-config instead of vendoring
              OPENSSL_NO_VENDOR = 1;
            };

            # app_config_path fails with permission denied in the sandbox
            checkFlags = [ "--skip=keys::key_config::tests::test_symbolic_links" ];

            meta = {
              description = "Blazing fast terminal-ui for Git written in Rust";
              homepage = "https://github.com/fredshonorio/gitui";
              license = lib.licenses.mit;
              mainProgram = "gitui";
            };
          };
          default = self.packages.${system}.gitui;
        }
      );

      overlays.default = final: _prev: {
        gitui = self.packages.${final.stdenv.hostPlatform.system}.gitui;
      };

      devShells = forAllSystems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in
        {
          default = pkgs.mkShell {
            inputsFrom = [ self.packages.${system}.gitui ];
            packages = with pkgs; [
              rust-analyzer
              clippy
              rustfmt
            ];
          };
        }
      );
    };
}
