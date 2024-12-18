# Issue

Running `crate2nix generate -f ./Cargo.toml -o not-IFD/Cargo-generated.nix -h not-IFD/crate-hashes.json` directly -> generates the tracked `not-IFD/Cargo-generated.nix` and `not-IFD/crate-hashes.json` files

In `flake.nix`, going from:
```nix
        cargoNixFile = ./not-IFD/Cargo-generated.nix;
        # cargoNixFile = ifdCargoNixFile;
```
to:
```nix
        # cargoNixFile = ./not-IFD/Cargo-generated.nix;
        cargoNixFile = ifdCargoNixFile;
```

crashes with the error described at https://github.com/nix-community/crate2nix/issues/348#issue-2274322372

Is also tracked in the IFD folder which `crate-hashes.json` it attempts to use.

This shows how the package ID used with IFD is not the same as would otherwise be generated by `cargo metadata`.
It seems that this may be what prevents it from matching the relevant packages: it's looking for an ID that's new `cargo metadata` format, but IFD-generated `crate-hashes.json` is old metadata format.

Package ID used by IFD is defined here: https://github.com/nix-community/crate2nix/blob/cf034861fdc4e091fc7c5f01d6c022dc46686cf1/tools.nix#L246-L249

More discussion here: https://github.com/nix-community/crate2nix/pull/341#issuecomment-2090407813
