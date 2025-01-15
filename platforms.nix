pkgs: let
  sol-version = "2.0.22";
in {
  platform-tools = rec {
    version = "v1.43";
    make = sys: hash:
      pkgs.fetchzip {
        url =
          "https://github.com/anya-xyz/platform-tools/releases/download/"
          + "${version}/platform-tools-${sys}.tar.bz2";
        sha256 = hash;
        stripRoot = false;
      };
    x86_64-linux =
      make "linux-x86_64" "sha256-e2qwEHNxjtqxjtBhgaKA0WkAF4LfKMHeYC0PUz/00Ts=";
    aarch64-darwin =
      make "osx-aarch64" "sha256-nijBgC8R0lxVsuPZI8m6JgT7rh4QcJWPG28V+RI3QUk=";
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
      make "x86_64-unknown-linux-gnu" "sha256:1vypvjlmgi1jp7g5pbb0nf5dn4hbhljr8diy3105dqa3rd2swz75";
    aarch64-darwin =
      make "aarch64-apple-darwin" "sha256:1ssqd987r8q9fximi9a5c34jx8k7hy265i4h45dlbrykkm7r7n2p";
    x86_64-darwin =
      make "x86_64-apple-darwin" "";
  };
  sol-version = sol-version;
}
