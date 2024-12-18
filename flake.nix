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
      url = "github:nix-community/crate2nix";
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
        cargoNix =
          pkgs.callPackage
            (crate2nix.tools.${system}.generatedCargoNix {
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
            })
            {
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

              pkgs.rust-bin.stable.latest.default # Make Rust available in the shell as well
              crate2nix.packages.${system}.default # Make crate2nix available in the shell as well
            ];
          }
        );
      }
    );
}
