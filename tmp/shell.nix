{ pkgs ? import <nixpkgs> {} }:

let
  isLinux = pkgs.stdenv.isLinux;
  isDarwin = pkgs.stdenv.isDarwin;

  # Common build tools
  commonTools = with pkgs; [
    # Host compiler (required for building host tools)
    gcc
    binutils

    gnumake
    bc
    flex
    bison
    perl
    python3
    ncurses
    openssl
    zlib
    lz4
    xz
    zstd
    dtc
    pkg-config
    cpio
  ];

  # Linux-only packages
  linuxTools = with pkgs; [
    elfutils
    libelf
    kmod
    pahole
  ];

  useCross = pkgs.stdenv.buildPlatform != pkgs.stdenv.hostPlatform;
  crossCompiler = pkgs.pkgsCross.aarch64-multiplatform.stdenv.cc;
  crossBinutils = pkgs.pkgsCross.aarch64-multiplatform.binutils;
  crossPrefix = if useCross then "aarch64-unknown-linux-gnu-" else "";

in pkgs.mkShell {
  name = "orangepi6plus-kernel-build";

  nativeBuildInputs = commonTools
    ++ (if useCross then [ crossCompiler crossBinutils ] else [])
    ++ (if isLinux then linuxTools else []);

  buildInputs = with pkgs; [
    ncurses
    openssl
    zlib
  ];

  HOSTCC = "gcc";
  HOSTCXX = "g++";

  shellHook = ''
    export ARCH=arm64
    export CROSS_COMPILE=${crossPrefix}
    export KERNEL_SRC="$(dirname "$(pwd)")"
    export HOSTCC=gcc
    export HOSTCXX=g++

    echo "========================================"
    echo "Orange Pi 6 Plus Kernel Build Environment"
    echo "========================================"
    echo ""
    echo "Kernel source: $KERNEL_SRC"
    echo "Architecture: $ARCH"
    echo "Cross compiler: $CROSS_COMPILE"
    echo "Host compiler: $HOSTCC"
    ${if isDarwin then ''
    echo ""
    echo "NOTE: Building on macOS. Some kernel features"
    echo "      requiring elfutils may not work."
    '' else ""}
    echo ""
    echo "Available commands:"
    echo "  ./build.sh              - Full kernel build"
    echo "  ./build.sh menuconfig   - Configure kernel"
    echo "  ./build.sh clean        - Clean build"
    echo "  ./build.sh defconfig    - Apply default config"
    echo ""
  '';
}
