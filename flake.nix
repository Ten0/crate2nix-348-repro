{
  description = "Repro for https://github.com/nix-community/crate2nix/issues/348";
  inputs = {
    nixpkgs.follows = "crate2nix/nixpkgs";
    flake-utils.url = "github:numtide/flake-utils";
    rust-overlay = {
      url = "github:oxalica/rust-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    crate2nix = {
      url = "github:nix-community/crate2nix?rev=8537c2d7cb623679aaeff62c4c4c43a91566ab09";
    };
  };

  nixConfig = {
    allow-import-from-derivation = true;
  };

  outputs =
    {
      nixpkgs,
      flake-utils,
      rust-overlay,
      crate2nix,
      ...
    }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = import nixpkgs {
          inherit system;
          overlays = [ (import rust-overlay) ];
        };
        lib = pkgs.lib;
        ifdCargoNixFile = (
          crate2nix.tools.${system}.generatedCargoNix {
            name = "repro-crate2nix-348";
            src = lib.fileset.toSource {
              root = ./.;
              fileset = lib.fileset.fromSource (
                lib.cleanSourceWith {
                  src = ./.;
                  filter =
                    path: type:
                    (
                      let
                        baseName = baseNameOf (toString path);
                      in
                      (
                        (type == "directory" && baseName != "target")
                        || (
                          baseName == "Cargo.toml"
                          || baseName == "Cargo.lock"
                          || baseName == "lib.rs"
                          || baseName == "main.rs"
                        )
                      )
                      && (lib.cleanSourceFilter path type) # + other basic filters
                    );
                }
              );
            };
            cargoToml = "./Cargo.toml";
          }
        );

        cargoNixFile = ./not-IFD/Cargo-generated.nix;
        # cargoNixFile = ifdCargoNixFile;
        cargoNix = pkgs.callPackage cargoNixFile {
          buildRustCrateForPkgs =
            pkgs:
            pkgs.buildRustCrate.override (
              let
                rustToolchain = pkgs.rust-bin.stable.latest;
              in
              {
                # Use the latest stable rust version from oxalica overlay instead of the one in nixpkgs to build workspace packages
                # https://github.com/NixOS/nixpkgs/blob/master/doc/languages-frameworks/rust.section.md
                # https://github.com/NixOS/nixpkgs/blob/master/pkgs/build-support/rust/build-rust-crate/default.nix#L12-L13
                rustc = rustToolchain.default;
                cargo = rustToolchain.cargo;
                # We need to override some dependencies/env variables... for some crates - that is specified in crate_overrides.nix
                defaultCrateOverrides = pkgs.callPackage ./crate_overrides.nix { inherit cargoNix; };
              }
            );
        };
        rustWorkspace = lib.mapAttrs (name: value: value.build) cargoNix.workspaceMembers;
      in
      {
        inherit rustWorkspace;
        devShells.default = (
          pkgs.mkShell {
            buildInputs = [
              rustWorkspace.project1

              # (pkgs.writeScriptBin "copy_ifd_generated_crate_hashes" ''
              #   #!/usr/bin/env bash
              #   mkdir -p IFD
              #   cp -r "${ifdCargoNixFile}" IFD
              # '')

              pkgs.rust-bin.stable.latest.default # Make Rust available in the shell as well
              crate2nix.packages.${system}.default # Make crate2nix available in the shell as well

              # To build lightgbm (this is detail and unrelated to the git resolution issue)
              pkgs.pkg-config
              pkgs.cmake
              pkgs.clang-tools
              pkgs.clang
            ];

            nativeBuildInputs = [
              # To build lightgbm (this is detail and unrelated to the git resolution issue)
              pkgs.gcc
            ];

            #shellHook = ''
            #  echo "IFD-generated crate-hashes.json: ${ifdCargoNixFile}/crate-hashes.json"
            #'';

            LIBCLANG_PATH = "${pkgs.libclang.lib}/lib";
          }
        );
      }
    );
}
