FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive

# Install kernel build dependencies
RUN apt-get update && apt-get install -y \
    build-essential \
    gcc-aarch64-linux-gnu \
    g++-aarch64-linux-gnu \
    binutils-aarch64-linux-gnu \
    bc \
    bison \
    flex \
    libssl-dev \
    libncurses-dev \
    libelf-dev \
    liblz4-tool \
    lz4 \
    xz-utils \
    zstd \
    device-tree-compiler \
    cpio \
    kmod \
    rsync \
    python3 \
    git \
    && rm -rf /var/lib/apt/lists/*

# Set up environment
ENV ARCH=arm64
ENV CROSS_COMPILE=aarch64-linux-gnu-

WORKDIR /kernel

# Default command
CMD ["/bin/bash"]
