#!/usr/bin/env bash
#
# Orange Pi 6 Plus Kernel Build Script
# Usage: ./build.sh [command]
#
# Commands:
#   defconfig   - Apply orangepi_6_plus_defconfig
#   menuconfig  - Interactive kernel configuration
#   build       - Build kernel, modules, and DTBs (default)
#   clean       - Clean build artifacts
#   mrproper    - Deep clean (removes .config too)
#   modules     - Build only modules
#   dtbs        - Build only device tree blobs
#   Image       - Build only kernel Image
#   help        - Show this help message
#

set -e

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KERNEL_SRC="$(dirname "$SCRIPT_DIR")"
OUTPUT_DIR="$SCRIPT_DIR/out"
DEFCONFIG="orangepi_6_plus_defconfig"
JOBS=$(nproc 2>/dev/null || sysctl -n hw.ncpu 2>/dev/null || echo 4)

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if we're in a Nix shell with the cross-compiler
check_environment() {
    if [ -z "$ARCH" ] || [ -z "$CROSS_COMPILE" ]; then
        log_warn "ARCH or CROSS_COMPILE not set. Setting defaults for ARM64 cross-compilation."
        export ARCH=arm64
        export CROSS_COMPILE=aarch64-unknown-linux-gnu-
    fi

    # Try to find the compiler
    if ! command -v ${CROSS_COMPILE}gcc &> /dev/null; then
        # Try alternative prefix
        if command -v aarch64-linux-gnu-gcc &> /dev/null; then
            export CROSS_COMPILE=aarch64-linux-gnu-
        elif command -v aarch64-none-linux-gnu-gcc &> /dev/null; then
            export CROSS_COMPILE=aarch64-none-linux-gnu-
        else
            log_error "Cross-compiler not found!"
            log_info "Please run this script inside the Nix shell:"
            log_info "  cd $SCRIPT_DIR && nix-shell"
            exit 1
        fi
    fi

    log_info "Using compiler: ${CROSS_COMPILE}gcc"
    log_info "Architecture: $ARCH"
}

# Common make arguments
make_args() {
    echo "-C $KERNEL_SRC O=$OUTPUT_DIR ARCH=$ARCH CROSS_COMPILE=$CROSS_COMPILE HOSTCC=${HOSTCC:-gcc} HOSTCXX=${HOSTCXX:-g++} -j$JOBS"
}

cmd_defconfig() {
    log_info "Applying $DEFCONFIG..."
    mkdir -p "$OUTPUT_DIR"
    make $(make_args) $DEFCONFIG
    log_success "Configuration applied successfully"
}

cmd_menuconfig() {
    log_info "Opening menuconfig..."
    if [ ! -f "$OUTPUT_DIR/.config" ]; then
        log_warn "No .config found, applying defconfig first..."
        cmd_defconfig
    fi
    make $(make_args) menuconfig
}

cmd_savedefconfig() {
    log_info "Saving minimal defconfig..."
    make $(make_args) savedefconfig
    log_success "Saved to $OUTPUT_DIR/defconfig"
}

cmd_build() {
    log_info "Starting full kernel build..."
    log_info "Using $JOBS parallel jobs"

    if [ ! -f "$OUTPUT_DIR/.config" ]; then
        log_warn "No .config found, applying defconfig first..."
        cmd_defconfig
    fi

    log_info "Building kernel Image..."
    make $(make_args) Image

    log_info "Building modules..."
    make $(make_args) modules

    log_info "Building device tree blobs..."
    make $(make_args) dtbs

    log_success "Build completed successfully!"
    log_info "Output files:"
    log_info "  Kernel Image: $OUTPUT_DIR/arch/arm64/boot/Image"
    log_info "  DTBs: $OUTPUT_DIR/arch/arm64/boot/dts/"
}

cmd_Image() {
    log_info "Building kernel Image only..."
    if [ ! -f "$OUTPUT_DIR/.config" ]; then
        cmd_defconfig
    fi
    make $(make_args) Image
    log_success "Kernel Image built: $OUTPUT_DIR/arch/arm64/boot/Image"
}

cmd_modules() {
    log_info "Building modules only..."
    if [ ! -f "$OUTPUT_DIR/.config" ]; then
        cmd_defconfig
    fi
    make $(make_args) modules
    log_success "Modules built successfully"
}

cmd_modules_install() {
    local install_path="${1:-$OUTPUT_DIR/modules_install}"
    log_info "Installing modules to $install_path..."
    make $(make_args) INSTALL_MOD_PATH="$install_path" modules_install
    log_success "Modules installed to $install_path"
}

cmd_dtbs() {
    log_info "Building DTBs only..."
    if [ ! -f "$OUTPUT_DIR/.config" ]; then
        cmd_defconfig
    fi
    make $(make_args) dtbs
    log_success "DTBs built successfully"
}

cmd_clean() {
    log_info "Cleaning build artifacts..."
    if [ -d "$OUTPUT_DIR" ]; then
        make $(make_args) clean
        log_success "Build cleaned"
    else
        log_warn "No output directory found, nothing to clean"
    fi
}

cmd_mrproper() {
    log_info "Deep cleaning (mrproper)..."
    if [ -d "$OUTPUT_DIR" ]; then
        rm -rf "$OUTPUT_DIR"
        log_success "Output directory removed"
    fi
    make -C "$KERNEL_SRC" mrproper
    log_success "Deep clean completed"
}

cmd_help() {
    cat << EOF
Orange Pi 6 Plus Kernel Build Script

Usage: $0 [command]

Commands:
  defconfig       Apply orangepi_6_plus_defconfig
  menuconfig      Interactive kernel configuration
  savedefconfig   Save current config as minimal defconfig
  build           Build kernel, modules, and DTBs (default)
  Image           Build only kernel Image
  modules         Build only modules
  modules_install Install modules (optionally specify path)
  dtbs            Build only device tree blobs
  clean           Clean build artifacts
  mrproper        Deep clean (removes .config and output dir)
  help            Show this help message

Environment:
  Kernel source: $KERNEL_SRC
  Output dir:    $OUTPUT_DIR
  Defconfig:     $DEFCONFIG
  Jobs:          $JOBS

To enter the Nix build environment:
  cd $SCRIPT_DIR && nix-shell

EOF
}

# Main
main() {
    local cmd="${1:-build}"

    check_environment

    case "$cmd" in
        defconfig)
            cmd_defconfig
            ;;
        menuconfig)
            cmd_menuconfig
            ;;
        savedefconfig)
            cmd_savedefconfig
            ;;
        build)
            cmd_build
            ;;
        Image|image)
            cmd_Image
            ;;
        modules)
            cmd_modules
            ;;
        modules_install)
            cmd_modules_install "$2"
            ;;
        dtbs)
            cmd_dtbs
            ;;
        clean)
            cmd_clean
            ;;
        mrproper)
            cmd_mrproper
            ;;
        help|-h|--help)
            cmd_help
            ;;
        *)
            log_error "Unknown command: $cmd"
            cmd_help
            exit 1
            ;;
    esac
}

main "$@"
