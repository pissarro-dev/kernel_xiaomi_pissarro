#!/bin/bash
#
# Compile script for Hydrogen kernel
# Brought to you by rio004 
#

SECONDS=0
DEVICE="pissarro"
DATE=$(date '+%Y%m%d-%H%M')
ZIPNAME="HydrogenKernel-${DEVICE}-${DATE}.zip"
TC_DIR="$HOME/tc/proton-clang"
DEFCONFIG="${DEVICE}_user_defconfig"

clone_repo() {
    local repo_url="$1"
    local target_dir="$2"
    if [ ! -d "$target_dir" ]; then
        echo "Cloning $repo_url to $target_dir..."
        git clone -q --depth=1 --single-branch "$repo_url" "$target_dir" || {
            echo "Cloning failed! Aborting..."
            exit 1
        }
    fi
}

# Ensure the toolchain is available
clone_repo https://github.com/kdrag0n/proton-clang "$TC_DIR"
export PATH="$TC_DIR/bin:$PATH"

# Process options
CLEAN_BUILD=false
INCLUDE_KSU=false
for arg in "$@"; do
    case $arg in
        -c) CLEAN_BUILD=true ;;
        -ksu) INCLUDE_KSU=true
             ZIPNAME="HydrogenKernel-KSU-${DEVICE}-${DATE}.zip"
             ;;
    esac
done

[ "$CLEAN_BUILD" = true ] && rm -rf out
[ "$INCLUDE_KSU" = true ] && echo "Save your stuff!!" && curl -LSs "https://raw.githubusercontent.com/tiann/KernelSU/main/kernel/setup.sh" | bash -

# Compilation process
mkdir -p out
make O=out ARCH=arm64 "$DEFCONFIG"

echo -e "\nStarting compilation...\n"
if make -j$(nproc --all) O=out ARCH=arm64 CC="ccache clang" LLVM=1 LLVM_IAS=1 CROSS_COMPILE=aarch64-linux-gnu- CROSS_COMPILE_ARM32=arm-linux-gnueabi- Image.gz dtbo.img; then
    echo -e "\nKernel compiled successfully! Zipping up...\n"
    clone_repo https://github.com/rio004/AnyKernel3 AnyKernel3
    cp out/arch/arm64/boot/{Image.gz,dtbo.img} AnyKernel3
    rm -rf *zip out/arch/arm64/boot
    (cd AnyKernel3 && zip -r9 "../$ZIPNAME" * -x '*.git*' README.md *placeholder)
    rm -rf AnyKernel3
    if [ "$INCLUDE_KSU" = true ]; then
        git restore drivers/{Makefile,Kconfig}
        rm -rf KernelSU drivers/kernelsu
    fi
    echo -e "\nCompleted in $((SECONDS / 60)) minute(s) and $((SECONDS % 60)) second(s)!"
    echo "Zip: $ZIPNAME"
else
    echo -e "\nCompilation failed!"
fi
