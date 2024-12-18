{
  pkgs,
  lib,
  cargoNix,
  cmake,
  clang-tools,
  clang,
  gcc,
}:

let
  overrides = {
    # old is the overrides proposed by nixpkgs, to which we add our own
    "lightgbm-sys" = old: crate: {
      buildInputs = (old.buildInputs or [ ]) ++ [ gcc ];
      nativeBuildInputs = (old.nativeBuildInputs or [ ]) ++ [
        cmake
        clang-tools
        clang
      ];
      LIBCLANG_PATH = "${pkgs.libclang.lib}/lib";
    };
  };

  # The overrides above, falling back to the default overrides provided by nixpkgs
  defaultOrOverrides =
    pkgs.defaultCrateOverrides
    // (builtins.mapAttrs (
      name: value:
      let
        defaultOverride = pkgs.defaultCrateOverrides.${name} or (crate: { });
      in
      crate:
      (
        let
          defaultOverrideApplied = defaultOverride crate;
        in
        lib.attrsets.recursiveUpdate defaultOverrideApplied (value defaultOverrideApplied crate)
      )
    ) overrides);

  # Enable debuginfo on all known crates. Unfortunately this has to be overridden on a per-crate basis,
  # and we can only do this by looking up crates list from cargoNix.internal.
  # The fact this is so complex is tracked by https://github.com/nix-community/crate2nix/issues/345
  extraRustFlags = [ "-C debuginfo=1" ];
  withAppliedExtraFlags =
    defaultOrOverrides
    // (builtins.listToAttrs (
      builtins.map (
        crate:
        let
          crateName = crate.crateName;
          defaultOverride = defaultOrOverrides.${crateName} or (crate: { });
        in
        {
          name = crateName;
          value =
            crate:
            (
              let
                defaultOverrideApplied = defaultOverride crate;
              in
              defaultOverrideApplied
              // {
                extraRustcOpts = (defaultOverrideApplied.extraRustcOpts or [ ]) ++ extraRustFlags;
                extraRustcOptsForBuildRs =
                  (defaultOverrideApplied.extraRustcOptsForBuildRs or [ ]) ++ extraRustFlags;
              }
            );
        }
      ) (builtins.attrValues cargoNix.internal.crates)
    ));
in
withAppliedExtraFlags
