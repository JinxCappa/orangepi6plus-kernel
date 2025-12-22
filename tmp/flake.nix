{
  description = "Orange Pi 6 Plus Kernel Build Environment";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = { self, nixpkgs }:
    let
      # Target system for kernel build
      system = "aarch64-linux";
      pkgs = import nixpkgs { inherit system; };

      defconfig = "orangepi_6_plus_defconfig";

      # Build inputs
      buildInputs = with pkgs; [
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
        elfutils
        libelf
        zlib
        lz4
        xz
        zstd
        dtc
        pkg-config
        cpio
        kmod
        ubootTools
        pahole
      ];

    in {
      # Development shell
      devShells.${system}.default = pkgs.mkShell {
        name = "orangepi6plus-kernel";
        nativeBuildInputs = buildInputs;

        shellHook = ''
          export ARCH=arm64
          export HOSTCC=gcc
          export HOSTCXX=g++

          echo "========================================"
          echo "Orange Pi 6 Plus Kernel Build Environment"
          echo "========================================"
          echo ""
          echo "Run: ./build.sh"
          echo ""
        '';
      };

      # Kernel package
      packages.${system} = rec {
        kernel = pkgs.stdenv.mkDerivation {
          pname = "orangepi6plus-kernel";
          version = "6.12";

          # sourceInfo.outPath gives the git root, not the subdirectory
          src = self.sourceInfo.outPath;

          nativeBuildInputs = buildInputs;

          makeFlags = [
            "ARCH=arm64"
            "HOSTCC=gcc"
            "HOSTCXX=g++"
          ];

          configurePhase = ''
            runHook preConfigure
            echo "=== Current directory ==="
            pwd
            echo "=== Directory contents ==="
            ls -la
            echo "=== Checking for arch ==="
            ls -la arch/arm64/configs/ || echo "No configs dir"
            make $makeFlags ${defconfig}
            runHook postConfigure
          '';

          buildPhase = ''
            runHook preBuild
            make $makeFlags -j$NIX_BUILD_CORES Image modules dtbs
            runHook postBuild
          '';

          installPhase = ''
            runHook preInstall

            mkdir -p $out/boot $out/dtbs $out/modules $out/lib/modules

            cp arch/arm64/boot/Image $out/boot/
            cp -r arch/arm64/boot/dts/cixtech $out/dtbs/ 2>/dev/null || true
            cp -r arch/arm64/boot/dts/rockchip $out/dtbs/ 2>/dev/null || true

            make $makeFlags INSTALL_MOD_PATH=$out/modules modules_install

            # Get kernel version for paths
            kernelVersion=$(make $makeFlags -s kernelrelease)

            # Create build directory with headers needed for out-of-tree module compilation
            buildDir=$out/lib/modules/$kernelVersion/build
            mkdir -p $buildDir

            # Copy essential files for module building
            cp .config $buildDir/
            cp Module.symvers $buildDir/
            cp Makefile $buildDir/

            # Copy scripts and tools needed for building
            cp -r scripts $buildDir/
            cp -r include $buildDir/

            # Remove broken symlinks in scripts/dtc/include-prefixes
            # These point to arch-specific DTS directories we don't copy
            if [ -d "$buildDir/scripts/dtc/include-prefixes" ]; then
              find $buildDir/scripts/dtc/include-prefixes -type l ! -exec test -e {} \; -delete
            fi

            # Copy arch-specific headers
            mkdir -p $buildDir/arch/arm64
            cp -r arch/arm64/include $buildDir/arch/arm64/
            cp -r arch/arm64/Makefile $buildDir/arch/arm64/

            # Copy Kconfig files (needed by some module builds)
            find . -name 'Kconfig*' -exec install -D -m644 {} $buildDir/{} \;

            # Fix the symlinks to point to our build directory
            rm -f $out/modules/lib/modules/$kernelVersion/build
            rm -f $out/modules/lib/modules/$kernelVersion/source
            ln -s $buildDir $out/modules/lib/modules/$kernelVersion/build
            ln -s $buildDir $out/modules/lib/modules/$kernelVersion/source

            runHook postInstall
          '';

          dontStrip = true;
        };

        default = kernel;
      };
    };
}
