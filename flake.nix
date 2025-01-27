{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
  };
  outputs = {
    nixpkgs,
    ...
  }: let
    forAllSystems = function:
      nixpkgs.lib.genAttrs [
        "x86_64-linux"
        "x86_64-darwin"
        "aarch64-darwin"
      ] (system: function nixpkgs.legacyPackages.${system});
  in {
    packages = forAllSystems (pkgs: let
      solana-pkgs = pkgs.callPackage ./default.nix {
        inherit pkgs;
      };
    in {
      solana = solana-pkgs.solana;
      solana-rust = solana-pkgs.solana-rust;
      anchor = solana-pkgs.anchor;
      default = pkgs.symlinkJoin {
        name = "solana-all";
        paths = [
          solana-pkgs.solana
          solana-pkgs.solana-rust
          solana-pkgs.anchor
        ];
      };
    });
  };
}
