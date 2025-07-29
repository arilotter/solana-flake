# Solana Flake

Building on the work of

- https://github.com/nasadorian/solflake
- https://github.com/itsfarseen/solana-flake

This flake provides:

## `solana-cli`

The full Solana CLI, including a functional build toolchain for the `cargo sbf` command.

## `solana-rust`

A `rustc` and `cargo` that can build for the Rust target `sbf-solana-solana`

## `anchor`

The full Anchor CLI, including a functional build toolchain for the `anchor build` command.

## Usage

Define your `flake.nix` like the one below. It will install other necessary dependencies like

- Nodejs and yarn
- rustup with stable toolchain

```nix
{
  description = "Solana and anchor flake";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs-unstable";
    rust-overlay.url = "github:oxalica/rust-overlay";
    solana.url = "github:arilotter/solana-flake";
  };

  outputs = { self, nixpkgs, rust-overlay, solana }:
    let
      pkgs = import nixpkgs {
        overlays = [ rust-overlay.overlays.default ];
        system = "x86_64-linux";
      };
    in
    {
      devShells.x86_64-linux.default = pkgs.mkShell {
        buildInputs = [
          pkgs.rustup
          solana.packages.x86_64-linux.default
          pkgs.nodejs_22
          pkgs.yarn
        ];

        shellHook = ''
          # Install the stable toolchain and set it as default
          if ! rustup show | grep -q 'stable'; then
            rustup install stable
            rustup default stable
          fi
        '';
      };
    };
}
```
