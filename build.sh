#!/usr/bin/env bash

 #
 # Script For Building Android Kernel
 #

if [ ! -d "${PWD}/kernel_ccache" ]; 
    then
    mkdir -p "${PWD}/kernel_ccache"
    fi
    export CCACHE_DIR="${PWD}/kernel_ccache"
    export CCACHE_EXEC=$(which ccache)
    export USE_CCACHE=1
    ccache -M 2G
    ccache -z

##----------------------------------------------------------##
# Specify Kernel Directory
KERNEL_DIR="$(pwd)"

##----------------------------------------------------------##
# Device Name and Model
MODEL=Xiaomi
DEVICE=Ginkgo

# Kernel Version Code
VERSION=V1.0

# Kernel Defconfig
DEFCONFIG=vendor/sixteen_defconfig

# Files
IMAGE=$(pwd)/out/arch/arm64/boot/Image.gz-dtb
DTBO=$(pwd)/out/arch/arm64/boot/dtbo.img
TRINKET=$(pwd)/arch/arm64/boot/dts/qcom/trinket.dtb

# Verbose Build
VERBOSE=0

# Kernel Version
KERVER=$(make kernelversion)

COMMIT_HEAD=$(git log --oneline -1)

# Date and Time
DATE=$(TZ=Asia/Jakarta date +"%Y%m%d-%T")
TANGGAL=$(date +"%F%S")

# Specify Final Zip Name
ZIPNAME=Wolf
FINAL_ZIP=${ZIPNAME}-${VERSION}-${DEVICE}-Kernel-${TANGGAL}.zip

##----------------------------------------------------------##
# Specify compiler.

if [ "$1" = "--eva" ];
then
COMPILER=eva
elif [ "$1" = "--proton" ];
then
COMPILER=proton
elif [ "$1" = "--aosp" ];
then
COMPILER=aosp
elif [ "$1" = "--azure" ];
then
COMPILER=azure
elif [ "$1" = "--sdm" ];
then
COMPILER=sdm
elif [ "$1" = "--neutron" ];
then
COMPILER=neutron
fi

##----------------------------------------------------------##
# Clone ToolChain
function cloneTC() {
	
	if [ $COMPILER = "neutron" ];
	then
	post_msg "|| Cloning Neutron Clang ToolChain ||"
	git clone --depth=1  https://github.com/Neutron-Clang/neutron-toolchain.git clang
	PATH="${KERNEL_DIR}/clang/bin:$PATH"
	
	elif [ $COMPILER = "proton" ];
	then
	post_msg "|| Cloning Proton Clang ToolChain ||"
	git clone --depth=1 https://github.com/kdrag0n/proton-clang -b master clang
	PATH="${KERNEL_DIR}/clang/bin:$PATH"
	
	elif [ $COMPILER = "azure" ];
	then
	post_msg "|| Cloning Azure Clang ToolChain ||"
	git clone --depth=1 https://gitlab.com/Panchajanya1999/azure-clang.git clang
	PATH="${KERNEL_DIR}/clang/bin:$PATH"
	
	elif [ $COMPILER = "eva" ];
	then
	post_msg "|| Cloning Eva GCC ToolChain ||"
	git clone --depth=1 https://github.com/mvaisakh/gcc-arm64 -b gcc-master gcc64
	git clone --depth=1 https://github.com/mvaisakh/gcc-arm -b gcc-master gcc32
	PATH=$KERNEL_DIR/gcc64/bin/:$KERNEL_DIR/gcc32/bin/:/usr/bin:$PATH
	
        elif [ $COMPILER = "sdm" ];
	then
	post_msg "|| Cloning Snapdragon Clang ToolChain ||"
	git clone --depth=1 https://github.com/ThankYouMario/proprietary_vendor_qcom_sdclang.git -b 14 clang
	PATH="${KERNEL_DIR}/clang/bin:$PATH"

	elif [ $COMPILER = "aosp" ];
	then
	post_msg "|| Cloning Aosp Clang 14.0.1 ToolChain ||"
        mkdir aosp-clang
        cd aosp-clang || exit
	wget -q https://android.googlesource.com/platform/prebuilts/clang/host/linux-x86/+archive/refs/heads/master/clang-r437112b.tar.gz
        tar -xf clang*
        cd .. || exit
	git clone https://github.com/LineageOS/android_prebuilts_gcc_linux-x86_aarch64_aarch64-linux-android-4.9.git --depth=1 gcc
	git clone https://github.com/LineageOS/android_prebuilts_gcc_linux-x86_arm_arm-linux-androideabi-4.9.git  --depth=1 gcc32
	PATH="${KERNEL_DIR}/aosp-clang/bin:${KERNEL_DIR}/gcc/bin:${KERNEL_DIR}/gcc32/bin:${PATH}"
	fi
        # Clone AnyKernel
        git clone --depth=1 https://github.com/tyuzu-xd/AnyKernel3 -b ginkgo

	}
	
##------------------------------------------------------##
# Export Variables
function exports() {
	
        # Export KBUILD_COMPILER_STRING
        if [ -d ${KERNEL_DIR}/clang ];
           then
               export KBUILD_COMPILER_STRING=$(${KERNEL_DIR}/clang/bin/clang --version | head -n 1 | perl -pe 's/\(http.*?\)//gs' | sed -e 's/  */ /g' -e 's/[[:space:]]*$//')
        elif [ -d ${KERNEL_DIR}/gcc64 ];
           then
               export KBUILD_COMPILER_STRING=$("$KERNEL_DIR/gcc64"/bin/aarch64-elf-gcc --version | head -n 1)
        elif [ -d ${KERNEL_DIR}/aosp-clang ];
            then
               export KBUILD_COMPILER_STRING=$(${KERNEL_DIR}/aosp-clang/bin/clang --version | head -n 1 | perl -pe 's/\(http.*?\)//gs' | sed -e 's/  */ /g' -e 's/[[:space:]]*$//')
        fi
        
        # Export ARCH and SUBARCH
        export ARCH=arm64
        export SUBARCH=arm64
        
        # Export Local Version
        export LOCALVERSION="-${VERSION}"
        
        # KBUILD HOST and USER
        export KBUILD_BUILD_HOST=Ubuntu
        export KBUILD_BUILD_USER="TyuzuXD"
        
        # CI
        if [ "$CI" ]
           then
               
           if [ "$CIRCLECI" ]
              then
                  export KBUILD_BUILD_VERSION=${CIRCLE_BUILD_NUM}
                  export CI_BRANCH=${CIRCLE_BRANCH}
           elif [ "$DRONE" ]
	      then
		  export KBUILD_BUILD_VERSION=${DRONE_BUILD_NUMBER}
		  export CI_BRANCH=${DRONE_BRANCH}
           fi
		   
        fi
	export PROCS=$(nproc --all)
	export DISTRO=$(source /etc/os-release && echo "${NAME}")
	}
        
##----------------------------------------------------------------##
# Telegram Bot Integration

function post_msg() {
	curl -s -X POST "https://api.telegram.org/bot$token/sendMessage" \
	-d chat_id="$chat_id" \
	-d "disable_web_page_preview=true" \
	-d "parse_mode=html" \
	-d text="$1"
	}

function push() {
	curl -F document=@$1 "https://api.telegram.org/bot$token/sendDocument" \
	-F chat_id="$chat_id" \
	-F "disable_web_page_preview=true" \
	-F "parse_mode=html" \
	-F caption="$2"
	}
	
##----------------------------------------------------------##
# Compilation
function compile() {
START=$(date +"%s")
	# Push Notification
	post_msg "<b>$KBUILD_BUILD_VERSION CI Build Triggered</b>%0A<b>Docker OS: </b><code>$DISTRO</code>%0A<b>Kernel Version : </b><code>$KERVER</code>%0A<b>Date : </b><code>$(TZ=Asia/Jakarta date)</code>%0A<b>Device : </b><code>$MODEL [$DEVICE]</code>%0A<b>Pipeline Host : </b><code>$KBUILD_BUILD_HOST</code>%0A<b>Host Core Count : </b><code>$PROCS</code>%0A<b>Compiler Used : </b><code>$KBUILD_COMPILER_STRING</code>%0A<b>Branch : </b><code>$CI_BRANCH</code>%0A<b>Top Commit : </b><a href='$DRONE_COMMIT_LINK'>$COMMIT_HEAD</a>"
	
	# Compile
	if [ -d ${KERNEL_DIR}/clang ];
	   then
           make -j$(nproc --all) O=$out \
           ARCH=arm64 \
           CC="clang" \
           AR="llvm-ar" \
           NM="llvm-nm" \
           LD="ld.lld" \
           AS="llvm-as" \
	   OBJCOPY="llvm-objcopy" \
           OBJDUMP="llvm-objdump" \
           CLANG_TRIPLE=aarch64-linux-gnu- \
           CROSS_COMPILE=aarch64-linux-gnu- \
           CROSS_COMPILE_ARM32=arm-linux-gnueabi-  
	   V=$VERBOSE 2>&1 | tee error.log
	elif [ -d ${KERNEL_DIR}/gcc64 ];
	   then
           make -j$(nproc --all) O=$out \
           ARCH=arm64 \
           CC="aarch64-elf-gcc" \
           AR="aarch64-elf-ar" \
           NM="aarch64-elf-nm" \
           LD="aarch64-elf-ld.bfd" \
           AS="aarch64-elf-as" \
           OBJCOPY="aarch64-elf-objcopy" \
           OBJDUMP="aarch64-elf-objdump" \
           CROSS_COMPILE_ARM32=$CROSS_COMPILE_ARM32
	       V=$VERBOSE 2>&1 | tee error.log
        elif [ -d ${KERNEL_DIR}/aosp-clang ];
           then
           make -j$(nproc --all) O=out \
	       ARCH=arm64 \
	       LLVM=1 \
	       LLVM_IAS=1 \
	       CLANG_TRIPLE=aarch64-linux-gnu- \
	       CROSS_COMPILE=aarch64-linux-android- \
	       CROSS_COMPILE_COMPAT=arm-linux-androideabi- \
	       V=$VERBOSE 2>&1 | tee error.log
	fi
	
	# Verify Files
	if ! [ -a "$IMAGE" ];
	   then
	       push "error.log" "Build Throws Errors"
	       exit 1
	   else
	       post_msg " Kernel Compilation Finished. Started Zipping "
	fi
	}

##----------------------------------------------------------------##
function zipping() {
	# Copy Files To AnyKernel3 Zip
	cp -f $IMAGE AnyKernel3
    cp -f $DTBO AnyKernel3
    cp -f $TRINKET AnyKernel3/dtb
	
	# Zipping and Push Kernel
	cd AnyKernel3 || exit 1
        zip -r9 ${FINAL_ZIP} *
        MD5CHECK=$(md5sum "$FINAL_ZIP" | cut -d' ' -f1)
        push "$FINAL_ZIP" "Build took : $(($DIFF / 60)) minute(s) and $(($DIFF % 60)) second(s) | For <b>$MODEL ($DEVICE)</b> | <b>${KBUILD_COMPILER_STRING}</b> | <b>MD5 Checksum : </b><code>$MD5CHECK</code>"
        cd ..
        }
    
##----------------------------------------------------------##

cloneTC
exports
compile
END=$(date +"%s")
DIFF=$(($END - $START))
zipping

##----------------*****-----------------------------##
