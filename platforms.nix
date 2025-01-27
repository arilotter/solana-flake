pkgs: let
  sol-version = "2.0.22";
in {
  platform-tools = rec {
    version = "v1.43";
    make = sys: hash:
      pkgs.fetchzip {
        url =
          "https://github.com/anza-xyz/platform-tools/releases/download/"
          + "${version}/platform-tools-${sys}.tar.bz2";
        sha256 = hash;
        stripRoot = false;
      };
    x86_64-linux =
      make "linux-x86_64" "sha256-GhMnfjKNJXpVqT1CZE0Zyp4+NXJG41sUxwHye9DGPt0=";
    aarch64-darwin =
      make "osx-aarch64" "";
    x86_64-darwin =
      make "osx-x86_64" "";
  };
  cli = rec {
    name = "solana-cli";
    version = sol-version;
    make = sys: hash:
      fetchTarball {
        url =
          "https://github.com/anza-xyz/agave/releases/download/"
          + "v${sol-version}/solana-release-${sys}.tar.bz2";
        sha256 = hash;
      };
    x86_64-linux =
      make "x86_64-unknown-linux-gnu" "sha256:02k8v0d11jrd3m3cld8pkzh7l9lkc525p1i96mx7n76f2h7s9ahn";
    aarch64-darwin =
      make "aarch64-apple-darwin" "sha256:1ssqd987r8q9fximi9a5c34jx8k7hy265i4h45dlbrykkm7r7n2p";
    x86_64-darwin =
      make "x86_64-apple-darwin" "";
  };
  sol-version = sol-version;
}
