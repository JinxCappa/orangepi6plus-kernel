# Orange Pi 6 Plus Kernel Build Scripts

Build environment for compiling the Linux 6.12 kernel for Orange Pi 6 Plus (ARM64).

## Quick Start (Docker - Recommended for macOS)

```bash
cd tmp

# Build the kernel (Docker image built automatically on first run)
./build-docker.sh

# Other commands
./build-docker.sh menuconfig   # Configure kernel
./build-docker.sh shell        # Interactive shell
./build-docker.sh help         # Show all commands
```

## Alternative: Nix (Linux only)

```bash
cd tmp

# Enter the Nix development shell
nix develop   # or: nix-shell

# Build the kernel
./build.sh
```

**Note:** The Nix setup only works on Linux. macOS lacks required headers (`elf.h`, etc.).

## Build Commands

| Command | Description |
|---------|-------------|
| `./build.sh` | Full build (kernel + modules + DTBs) |
| `./build.sh defconfig` | Apply orangepi_6_plus_defconfig |
| `./build.sh menuconfig` | Interactive kernel configuration |
| `./build.sh Image` | Build only the kernel Image |
| `./build.sh modules` | Build only kernel modules |
| `./build.sh dtbs` | Build only device tree blobs |
| `./build.sh clean` | Clean build artifacts |
| `./build.sh mrproper` | Deep clean (removes config too) |
| `./build.sh help` | Show all available commands |

## Output

Build artifacts are placed in `tmp/out/`:

- **Kernel Image**: `out/arch/arm64/boot/Image`
- **DTBs**: `out/arch/arm64/boot/dts/`
- **Modules**: Run `./build.sh modules_install` to install

## Customization

Edit `build.sh` to change:
- `DEFCONFIG` - Default kernel configuration
- `JOBS` - Number of parallel build jobs
- `OUTPUT_DIR` - Build output directory

## Environment Variables

The Nix shell sets:
- `ARCH=arm64`
- `CROSS_COMPILE=aarch64-unknown-linux-gnu-`
