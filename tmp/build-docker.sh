#!/usr/bin/env bash
#
# Orange Pi 6 Plus Kernel Build Script (Docker)
# Usage: ./build-docker.sh [command]
#
# Commands:
#   defconfig   - Apply orangepi_6_plus_defconfig
#   menuconfig  - Interactive kernel configuration
#   build       - Build kernel, modules, and DTBs (default)
#   clean       - Clean build artifacts
#   shell       - Open interactive shell in container
#   help        - Show this help message
#

set -e

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KERNEL_SRC="$(dirname "$SCRIPT_DIR")"
OUTPUT_DIR="$SCRIPT_DIR/out"
DEFCONFIG="orangepi_6_plus_defconfig"
IMAGE_NAME="orangepi6plus-kernel-builder"
CONTAINER_KERNEL="/kernel"
CONTAINER_OUT="/kernel/tmp/out"
JOBS=$(nproc 2>/dev/null || sysctl -n hw.ncpu 2>/dev/null || echo 4)

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Check Docker is available
check_docker() {
    if ! command -v docker &> /dev/null; then
        log_error "Docker not found. Please install Docker."
        exit 1
    fi
    if ! docker info &> /dev/null; then
        log_error "Docker daemon not running. Please start Docker."
        exit 1
    fi
}

# Build the Docker image
build_image() {
    if ! docker image inspect "$IMAGE_NAME" &> /dev/null; then
        log_info "Building Docker image (first time only)..."
        docker build -t "$IMAGE_NAME" "$SCRIPT_DIR"
        log_success "Docker image built successfully"
    fi
}

# Run command in Docker
docker_run() {
    local interactive=""
    if [ -t 0 ]; then
        interactive="-it"
    fi

    docker run --rm $interactive \
        -v "$KERNEL_SRC:$CONTAINER_KERNEL" \
        -w "$CONTAINER_KERNEL" \
        -e ARCH=arm64 \
        -e CROSS_COMPILE=aarch64-linux-gnu- \
        "$IMAGE_NAME" \
        "$@"
}

# Make command with common args
docker_make() {
    docker_run make O="$CONTAINER_OUT" ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- -j"$JOBS" "$@"
}

cmd_defconfig() {
    log_info "Applying $DEFCONFIG..."
    mkdir -p "$OUTPUT_DIR"
    docker_make "$DEFCONFIG"
    log_success "Configuration applied"
}

cmd_menuconfig() {
    log_info "Opening menuconfig..."
    if [ ! -f "$OUTPUT_DIR/.config" ]; then
        log_warn "No .config found, applying defconfig first..."
        cmd_defconfig
    fi
    docker_run make O="$CONTAINER_OUT" ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- menuconfig
}

cmd_build() {
    log_info "Starting full kernel build..."
    log_info "Using $JOBS parallel jobs"

    if [ ! -f "$OUTPUT_DIR/.config" ]; then
        log_warn "No .config found, applying defconfig first..."
        cmd_defconfig
    fi

    log_info "Building kernel Image..."
    docker_make Image

    log_info "Building modules..."
    docker_make modules

    log_info "Building device tree blobs..."
    docker_make dtbs

    log_success "Build completed!"
    log_info "Output files:"
    log_info "  Kernel: $OUTPUT_DIR/arch/arm64/boot/Image"
    log_info "  DTBs:   $OUTPUT_DIR/arch/arm64/boot/dts/"
}

cmd_Image() {
    log_info "Building kernel Image..."
    if [ ! -f "$OUTPUT_DIR/.config" ]; then
        cmd_defconfig
    fi
    docker_make Image
    log_success "Kernel Image built: $OUTPUT_DIR/arch/arm64/boot/Image"
}

cmd_modules() {
    log_info "Building modules..."
    if [ ! -f "$OUTPUT_DIR/.config" ]; then
        cmd_defconfig
    fi
    docker_make modules
    log_success "Modules built"
}

cmd_dtbs() {
    log_info "Building DTBs..."
    if [ ! -f "$OUTPUT_DIR/.config" ]; then
        cmd_defconfig
    fi
    docker_make dtbs
    log_success "DTBs built"
}

cmd_clean() {
    log_info "Cleaning..."
    if [ -d "$OUTPUT_DIR" ]; then
        docker_make clean
        log_success "Cleaned"
    fi
}

cmd_mrproper() {
    log_info "Deep clean..."
    rm -rf "$OUTPUT_DIR"
    docker_run make mrproper
    log_success "Deep clean done"
}

cmd_shell() {
    log_info "Opening shell in container..."
    docker_run /bin/bash
}

cmd_help() {
    cat << EOF
Orange Pi 6 Plus Kernel Build Script (Docker)

Usage: $0 [command]

Commands:
  defconfig    Apply orangepi_6_plus_defconfig
  menuconfig   Interactive kernel configuration
  build        Build kernel, modules, and DTBs (default)
  Image        Build only kernel Image
  modules      Build only modules
  dtbs         Build only device tree blobs
  clean        Clean build artifacts
  mrproper     Deep clean
  shell        Open interactive shell in container
  help         Show this help

Output: $OUTPUT_DIR
Jobs:   $JOBS

EOF
}

main() {
    local cmd="${1:-build}"

    check_docker
    build_image

    case "$cmd" in
        defconfig)    cmd_defconfig ;;
        menuconfig)   cmd_menuconfig ;;
        build)        cmd_build ;;
        Image|image)  cmd_Image ;;
        modules)      cmd_modules ;;
        dtbs)         cmd_dtbs ;;
        clean)        cmd_clean ;;
        mrproper)     cmd_mrproper ;;
        shell)        cmd_shell ;;
        help|-h|--help) cmd_help ;;
        *)
            log_error "Unknown command: $cmd"
            cmd_help
            exit 1
            ;;
    esac
}

main "$@"
