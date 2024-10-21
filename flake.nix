{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    # only temporarily needed - platform tools will do a release in a few months
    # that removes the requirement for python 3.8.
    # see https://github.com/anza-xyz/platform-tools/issues/79
    nixpkgs-python.url = "github:cachix/nixpkgs-python";
  };
  outputs = {
    nixpkgs,
    nixpkgs-python,
    ...
  }: let
    forAllSystems = function:
      nixpkgs.lib.genAttrs [
        "x86_64-linux"
        "x86_64-darwin"
        "aarch64-darwin"
      ] (system: function nixpkgs.legacyPackages.${system} nixpkgs-python.packages.${system});
  in {
    packages = forAllSystems (pkgs: python: let
      solana-pkgs = pkgs.callPackage ./default.nix {
        inherit pkgs python;
      };
    in {
      solana-cli = solana-pkgs.solana-cli;
      solana-rust = solana-pkgs.solana-rust;
      anchor = solana-pkgs.anchor;
    });
  };
}
