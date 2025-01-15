{
  pkgs,
  python,
}:
with pkgs; rec {
  platforms = import ./platforms.nix pkgs;

  solana-source = pkgs.fetchFromGitHub {
    owner = "solana-labs";
    repo = "solana";
    rev = "v${platforms.sol-version}";
    fetchSubmodules = true;
    sha256 = "sha256-ha+0P/XTI05LUd8CCzKMxrRkLThRN6jj6fn3d03HFyk=";
  };

  solana-cargo-build-sbf = with pkgs;
    rustPlatform.buildRustPackage {
      pname = "solana-cargo-build-sbf";
      version = platforms.sol-version;

      src = solana-source;
      buildAndTestSubdir = "sdk/cargo-build-sbf";

      cargoLock = {
        lockFile = "${solana-source}/Cargo.lock";
        outputHashes = {
          "crossbeam-epoch-0.9.5" = "sha256-Jf0RarsgJiXiZ+ddy0vp4jQ59J9m0k3sgXhWhCdhgws=";
          "aes-gcm-siv-0.10.3" = "sha256-N1ppxvew4B50JQWsC3xzP0X4jgyXZ5aOQ0oJMmArjW8=";
          "curve25519-dalek-3.2.1" = "sha256-FuVNFuGCyHXqKqg+sn3hocZf1KMCI092Ohk7cvLPNjQ=";
          "tokio-1.29.1" = "sha256-Z/kewMCqkPVTXdoBcSaFKG5GSQAdkdpj3mAzLLCjjGk=";
        };
      };

      nativeBuildInputs = [
        pkg-config
        perl
        cmake
        clang
        libclang.lib
      ];

      buildInputs = [
        udev
        clang
        libclang.lib
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
    nativeBuildInputs = [autoPatchelfHook];
    buildInputs =
      [
        # Auto patching
        zlib
        stdenv.cc.cc
        openssl
        libclang.lib
        xz
        python."3.8"
      ]
      ++ lib.optionals stdenv.isLinux [udev];

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

      cp -ar ${solana-source}/sdk/sbf/* $out/bin/sdk/sbf/
    '';
  };
  solana = stdenv.mkDerivation {
    name = "solana";
    version = platforms.cli.version;
    src = platforms.cli.${system};
    nativeBuildInputs = [autoPatchelfHook makeWrapper];

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
        --set RUSTC "${solana-platform-tools}/bin/sdk/sbf/dependencies/platform-tools/rust/bin/rustc"
    '';
  };

  solana-rust = stdenv.mkDerivation {
    name = "solana-rust";
    version = platforms.cli.version;
    src = platforms.cli.${system};
    nativeBuildInputs = [autoPatchelfHook makeWrapper];

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
    version = "0.30.1";

    src = fetchFromGitHub {
      owner = "coral-xyz";
      repo = "anchor";
      rev = "v${version}";
      hash = "sha256-NL8ySfvnCGKu1PTU4PJKTQt+Vsbcj+F1YYDzu0mSUoY=";
      fetchSubmodules = true;
    };

    cargoLock = {
      lockFileContents = builtins.readFile ./AnchorCargo.lock;
      outputHashes = {
        "serum_dex-0.4.0" = "sha256-Nzhh3OcAFE2LcbUgrA4zE2TnUMfV0dD4iH6fTi48GcI=";
      };
    };

    postPatch = ''
      rm Cargo.lock
      ln -s ${./AnchorCargo.lock} Cargo.lock
    '';

    buildInputs = lib.optionals stdenv.isDarwin [
      darwin.apple_sdk.frameworks.Security
      darwin.apple_sdk.frameworks.SystemConfiguration
    ];

    nativeBuildInputs = [makeWrapper];

    cargoPatches = [./anchor-idl-build.diff];

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
