{
  pkgs,
}:
with pkgs;
rec {
  platforms = import ./platforms.nix pkgs;

  agave-src = pkgs.fetchFromGitHub {
    owner = "anza-xyz";
    repo = "agave";
    rev = "v${platforms.sol-version}";
    fetchSubmodules = true;
    sha256 = "sha256-3wvXHY527LOvQ8b4UfXoIKSgwDq7Sm/c2qqj2unlN6I=";
  };

  solana-cargo-build-sbf =
    with pkgs;
    rustPlatform.buildRustPackage {
      pname = "solana-cargo-build-sbf";
      version = platforms.sol-version;

      src = agave-src;
      buildAndTestSubdir = "sdk/cargo-build-sbf";

      cargoLock = {
        lockFile = "${agave-src}/Cargo.lock";
        outputHashes = {
          "crossbeam-epoch-0.9.5" = "sha256-Jf0RarsgJiXiZ+ddy0vp4jQ59J9m0k3sgXhWhCdhgws=";
          "curve25519-dalek-3.2.1" = "sha256-4MF/qaP+EhfYoRETqnwtaCKC1tnUJlBCxeOPCnKrTwQ=";
          "tokio-1.29.1" = "sha256-Z/kewMCqkPVTXdoBcSaFKG5GSQAdkdpj3mAzLLCjjGk=";
        };
      };

      nativeBuildInputs = [
        pkg-config
        perl
        cmake
        clang
        libclang.lib
        protobuf
      ];

      buildInputs = [
        udev
        clang
        libclang.lib
        libedit
      ];

      LIBCLANG_PATH = "${libclang.lib}/lib";
      NIX_CFLAGS_COMPILE = "-I${libclang.lib}/clang/11.1.0/include";

      doCheck = false;

      cargoPatches = [
        ./cargo-build-sbf-main.diff
      ];
    };

  solana-platform-tools = stdenv.mkDerivation rec {
    name = "solana-platform-tools";
    version = platforms.platform-tools.version;
    src = platforms.platform-tools.${system};
    nativeBuildInputs = [ autoPatchelfHook ];
    buildInputs = [
      # Auto patching
      zlib
      stdenv.cc.cc
      openssl
      libclang.lib
      xz
      python310
      libedit
    ] ++ lib.optionals stdenv.isLinux [ udev ];

    preFixup = ''
      for file in $(find $out -type f -executable); do
        if patchelf --print-needed "$file" 2>/dev/null | grep -q "libedit.so.2"; then
          patchelf --replace-needed libedit.so.2 libedit.so.0.0.74 "$file"
        fi
      done
    '';

    installPhase = ''
      platformtools=$out/bin/sdk/sbf/dependencies/platform-tools
      mkdir -p $platformtools
      cp -r $src/llvm $platformtools;
      cp -r $src/rust $platformtools;
      ls -la $platformtools;
      chmod 0755 -R $out;
      touch $platformtools-${version}.md

      # Criterion is also needed
      criterion=$out/bin/sdk/sbf/dependencies/criterion
      mkdir $criterion
      ln -s ${criterion.dev}/include $criterion/include
      ln -s ${criterion}/lib $criterion/lib
      ln -s ${criterion}/share $criterion/share
      touch $criterion-v${criterion.version}.md

      cp -ar ${agave-src}/sdk/sbf/* $out/bin/sdk/sbf/
    '';
  };
  solana = stdenv.mkDerivation {
    name = "solana";
    version = platforms.cli.version;
    src = platforms.cli.${system};
    nativeBuildInputs = [
      autoPatchelfHook
      makeWrapper
    ];

    buildInputs = with pkgs; [
      solana-platform-tools
      stdenv.cc.cc.lib
      libgcc
      ocl-icd
      udev
      sgx-sdk
      zlib
    ];

    installPhase = ''
      mkdir -p $out/bin/sdk/sbf/dependencies
      cp -r $src/* $out
      ln -s ${solana-platform-tools}/bin/sdk/sbf/dependencies/platform-tools $out/bin/sdk/sbf/dependencies/platform-tools
      ln -s $out/bin/ld.lld $out/bin/ld
      cp -rf ${solana-cargo-build-sbf}/* $out
      chmod 0755 -R $out

      # Wrap cargo-build-sbf binary
      mv $out/bin/cargo-build-sbf $out/bin/.cargo-build-sbf-unwrapped
      makeWrapper $out/bin/.cargo-build-sbf-unwrapped $out/bin/cargo-build-sbf \
        --set SBF_SDK_PATH "${solana-platform-tools}/bin/sdk/sbf" \
        --set RUSTC "${solana-platform-tools}/bin/sdk/sbf/dependencies/platform-tools/rust/bin/rustc"
    '';
  };

  solana-rust = stdenv.mkDerivation {
    name = "solana-rust";
    version = platforms.cli.version;
    src = platforms.cli.${system};
    nativeBuildInputs = [
      autoPatchelfHook
      makeWrapper
    ];

    buildInputs = with pkgs; [
      solana-platform-tools
      stdenv.cc.cc.lib
      libgcc
      ocl-icd
      udev
      sgx-sdk
      zlib
    ];

    installPhase = ''
      mkdir -p $out/bin/sdk/sbf/dependencies
      cp -r $src/* $out
      ln -s ${solana-platform-tools}/bin/sdk/sbf/dependencies/platform-tools $out/bin/sdk/sbf/dependencies/platform-tools
      ln -s $out/bin/ld.lld $out/bin/ld

      cp -rf ${solana-platform-tools}/bin/sdk/sbf/dependencies/platform-tools/rust/* $out
      chmod 0755 -R $out
    '';
  };

  anchor = rustPlatform.buildRustPackage rec {
    pname = "anchor";
    version = "pre";

    src = fetchFromGitHub {
      owner = "coral-xyz";
      repo = "anchor";
      rev = "a7a23eea308440a9fa9cb79cee7bddd30ab163d5";
      hash = "sha256-xqKZxxKOjw1QFVfA9pNTvbcbP+ZWF0BpDCBlN6RjBNg=";
      fetchSubmodules = true;
    };

    cargoHash = "sha256-popy49tMI0SFa0WA33+avB5JQ2jiIEmGRXtRkSjOtvs=";

    nativeBuildInputs = [ makeWrapper ];

    cargoPatches = [ ./anchor-idl-build.diff ];

    checkFlags = [
      "--skip=tests::test_check_and_get_full_commit_when_full_commit"
      "--skip=tests::test_check_and_get_full_commit_when_partial_commit"
      "--skip=tests::test_get_anchor_version_from_commit"
    ];

    postInstall = ''
      mv $out/bin/anchor $out/bin/.anchor-unwrapped
      makeWrapper $out/bin/.anchor-unwrapped $out/bin/anchor \
        --set RUSTC "${solana-platform-tools}/bin/sdk/sbf/dependencies/platform-tools/rust/bin/rustc"
    '';
  };
}
