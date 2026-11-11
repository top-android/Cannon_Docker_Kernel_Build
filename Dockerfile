FROM ubuntu:22.04
ENV DEBIAN_FRONTEND=noninteractive
RUN apt update -y && apt install -y \
    git wget curl tar zip unzip make binutils bison flex libssl-dev bc libelf-dev \
    gcc-aarch64-linux-gnu gcc-arm-linux-gnueabi build-essential python3 \
    libncurses5-dev libncursesw5-dev pkg-config ccache && \
    apt clean && rm -rf /var/lib/apt/lists/*
WORKDIR /cannon

# Clang r596125 —— 和 LineageOS 24.0（Android 17）源码树里的 prebuilts/clang 完全一致
#   commit e7a1fa9e953f2d3ffba29f1436e9124977df813c 取自 AOSP 标签 android-17.0.0_r1
#   验证：clang/bin/clang --version → Android (15071444, ...) clang version 22.0.2 ... based on r596125
# 历史版本下载地址（低版本 ROM / 旧分支调用时改下面两行即可）：
#   r487747c（LOS 21 / Android 14，clang 17.0.2）：
#     https://android.googlesource.com/platform/prebuilts/clang/host/linux-x86/+archive/7154d3eddcb62ff7909a6ae2bf0c03e445e65bc4/clang-r487747c.tar.gz
#   r547379（LOS 22 / Android 15，clang 20.0.0）：
#     https://android.googlesource.com/platform/prebuilts/clang/host/linux-x86/+archive/refs/tags/android-16.0.0_r1/clang-r547379.tar.gz
#   r584948（LOS 23 / Android 16，clang 22.0.0）：
#     https://android.googlesource.com/platform/prebuilts/clang/host/linux-x86/+archive/refs/tags/android-16.0.0_r1/clang-r584948.tar.gz
#   现行：r596125（LOS 24 / Android 17，clang 22.0.2）见下
RUN wget -O /tmp/clang.tgz \
      'https://android.googlesource.com/platform/prebuilts/clang/host/linux-x86/+archive/e7a1fa9e953f2d3ffba29f1436e9124977df813c/clang-r596125.tar.gz' && \
    mkdir -p clang && tar -C clang -zxf /tmp/clang.tgz && rm -f /tmp/clang.tgz

# GCC 4.9（只作 CROSS_COMPILE 前缀，实际 CC=clang）
RUN wget -O /tmp/gcc64.tgz https://android.googlesource.com/platform/prebuilts/gcc/linux-x86/aarch64/aarch64-linux-android-4.9/+archive/refs/tags/android-12.1.0_r27.tar.gz && \
    mkdir -p gcc64 && tar -C gcc64 -zxf /tmp/gcc64.tgz && \
    wget -O /tmp/gcc32.tgz https://android.googlesource.com/platform/prebuilts/gcc/linux-x86/arm/arm-linux-androideabi-4.9/+archive/refs/tags/android-12.1.0_r27.tar.gz && \
    mkdir -p gcc32 && tar -C gcc32 -zxf /tmp/gcc32.tgz && \
    rm -f /tmp/gcc64.tgz /tmp/gcc32.tgz

# 内核源码（分支：lineage-21-cannon / next / ksu / next-susfs / next-susfs-new / cannon-a17-susfs-new）
RUN git clone https://github.com/top-android/android_kernel_xiaomi_cannon.git kernel

# AnyKernel3（打包成可刷 zip）+ anykernel.sh 依赖的 dtb / dtbo / config
RUN wget -O /tmp/ak.zip https://github.com/GTian5418/AnyKernel3/archive/refs/heads/cannon.zip && \
    unzip -q /tmp/ak.zip -d /tmp && mv /tmp/AnyKernel3-cannon /cannon/Anykernel && \
    rm -f /tmp/ak.zip /cannon/Anykernel/LICENSE /cannon/Anykernel/README.md && \
    wget -O /cannon/Anykernel/dtb.img  https://github.com/GTian5418/android_kernel_xiaomi_cannon/releases/download/Kernel/dtb.img && \
    wget -O /cannon/Anykernel/dtbo.img https://github.com/GTian5418/android_kernel_xiaomi_cannon/releases/download/Kernel/dtbo.img && \
    wget -O /tmp/config.zip https://github.com/GTian5418/android_kernel_xiaomi_cannon/releases/download/Kernel/config.zip && \
    unzip -q /tmp/config.zip -d /cannon && rm -f /tmp/config.zip

COPY build.sh /cannon/build.sh
RUN chmod +x /cannon/build.sh

# 产物会被拷到 /output（运行时 -v 挂载）
CMD ["/bin/bash", "-c", "/cannon/build.sh && mkdir -p /output && cp /cannon/dist/*.zip /output/"]
