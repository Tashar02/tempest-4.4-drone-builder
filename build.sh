#!/bin/bash
# SPDX-License-Identifier: GPL-3.0
# Copyright © 2021,
# Author(s): Divyanshu-Modi <divyan.m05@gmail.com>, Tashfin Shakeer Rhythm <tashfinshakeerrhythm@gmail.com>
# Revision: 26-09-2022

	VERSION='7.0'
	COMPILER="$1"

# USER
	USER='Tashar'
	HOST='Endeavour'

# DEVICE CONFIG
	DEVICENAME='Mi A2 / Mi 6X'
	DEVICE='wayne'
	DEVICE2='jasmine'
	CAM_LIB='3'
	HAPTICS='2'

# PATH
	KERNEL_DIR="$HOME/Kernel"
	ZIP_DIR="$HOME/Repack"
	AKSH="$ZIP_DIR/anykernel.sh"

# DEFCONFIG
if [[ "$CAM_LIB" == "1" ]]; then
	DFCF="vendor/${DEVICE}-perf_defconfig"
elif [[ "$CAM_LIB" == "2" ]]; then
	DFCF="vendor/${DEVICE}-old-perf_defconfig"
elif [[ "$CAM_LIB" == "3" ]]; then
	DFCF="vendor/${DEVICE}-oss-perf_defconfig"
fi
CONFIG="$KERNEL_DIR/arch/arm64/configs/$DFCF"

# Set variables
	if [[ "$COMPILER" == "CLANG" ]]; then
		CC='clang'
		HOSTCC="$CC"
		HOSTCXX="$CC++"
		CC_64='aarch64-linux-gnu-'
		C_PATH="$HOME/clang"
		sed -i '/CONFIG_SOUND_CONTROL=y/ a CONFIG_LTO_CLANG_FULL=y' $CONFIG
	elif [[ "$COMPILER" == "GCC" ]]; then
		HOSTCC='gcc'
		CC_64='aarch64-elf-'
		CC='aarch64-elf-gcc'
		HOSTCXX='aarch64-elf-g++'
		C_PATH="$HOME/gcc-arm64"
	fi
		CC_32="$HOME/gcc-arm32/bin/arm-eabi-"
		CC_COMPAT="$HOME/gcc-arm32/bin/arm-eabi-gcc"

	muke() {
		make O=$COMPILER $CFLAG ARCH=arm64   \
		    $FLAG                            \
			CC=$CC                           \
			LLVM=1                           \
			LLVM_IAS=1                       \
			PYTHON=python3                   \
			KBUILD_BUILD_USER=$USER          \
			KBUILD_BUILD_HOST=$HOST          \
			AS=llvm-as                       \
			AR=llvm-ar                       \
			NM=llvm-nm                       \
			LD=ld.lld                        \
			STRIP=llvm-strip                 \
			OBJCOPY=llvm-objcopy             \
			OBJDUMP=llvm-objdump             \
			OBJSIZE=llvm-objsize             \
			HOSTLD=ld.lld                    \
			HOSTCC=$HOSTCC                   \
			HOSTCXX=$HOSTCXX                 \
			HOSTAR=llvm-ar                   \
			PATH=$C_PATH/bin:$PATH           \
			CROSS_COMPILE=$CC_64             \
			CC_COMPAT=$CC_COMPAT             \
			CROSS_COMPILE_COMPAT=$CC_32      \
			LD_LIBRARY_PATH=$C_PATH/lib:$LD_LIBRARY_PATH \
			2>&1 | tee log.txt
	}

	CFLAG=$DFCF
	muke

	source $COMPILER/.config
	if [[ "$CONFIG_LTO_CLANG_THIN" != "y" && "$CONFIG_LTO_CLANG_FULL" == "y" ]]; then
		VARIANT='FULL_LTO'
	elif [[ "$CONFIG_LTO_CLANG_THIN" == "y" && "$CONFIG_LTO_CLANG_FULL" == "y" ]]; then
		VARIANT='THIN_LTO'
	else
		VARIANT='NON_LTO'
	fi
	telegram-send --format html "Building: <code>$VARIANT</code>"

	BUILD_START=$(date +"%s")

	CFLAG=-j$(nproc --all)
	muke

	BUILD_END=$(date +"%s")

	if [[ -f $KERNEL_DIR/$COMPILER/arch/arm64/boot/Image.gz-dtb ]]; then
		FDEVICE=${DEVICE^^}
		FDEVICE2=${DEVICE2^^}
		KNAME=$(echo "$CONFIG_LOCALVERSION" | cut -c 2-)
		
case $CAM_LIB in 
	1)
	   CAM=NEW-CAM
	;;
	2)
	   CAM=OLD-CAM
	;;
	3)
	   CAM=OSS-CAM
	;;
esac

case $HAPTICS in
	1)
		HAPTIC=QPNP
	;;
	2)
		HAPTIC=QTI
	;;
esac
		cp $KERNEL_DIR/$COMPILER/arch/arm64/boot/Image.gz-dtb $ZIP_DIR/

		cd $ZIP_DIR

		FINAL_ZIP="$KNAME-$CAM-$HAPTIC-$FDEVICE2-$FDEVICE-$(date +"%H%M")"
		zip -r9 "$FINAL_ZIP".zip * -x README.md LICENSE FUNDING.yml *placeholder zipsigner*
		java -jar zipsigner* "$FINAL_ZIP.zip" "$FINAL_ZIP-signed.zip"
		FINAL_ZIP="$FINAL_ZIP-signed.zip"

		telegram-send --file $ZIP_DIR/$FINAL_ZIP
		telegram-send --file $KERNEL_DIR/log.txt

		rm *.zip Image.gz-dtb

		cd $KERNEL_DIR

		DIFF=$(($BUILD_END - $BUILD_START))
		COMPILER_NAME="$($C_PATH/bin/$CC --version 2>/dev/null | head -n 1 | perl -pe 's/\(http.*?\)//gs' | sed -e 's/  */ /g' -e 's/[[:space:]]*$//')"

		telegram-send --disable-web-page-preview --format html "\
		========Scarlet-X Kernel========
		Compiler-name: <code>$COMPILER_NAME</code>
		Linux Version: <code>$(make kernelversion)</code>
		Builder Version: <code>$VERSION</code>
		Build Type: <code>$VARIANT</code>
		Maintainer: <code>$USER</code>
		Device: <code>$DEVICENAME</code>
		Codename: <code>$DEVICE</code>
		Zipname: <code>$FINAL_ZIP</code>
		Camlib: <code>$CAM</code>
		Build Date: <code>$(date +"%Y-%m-%d %H:%M")</code>
		Build Duration: <code>$(($DIFF / 60)).$(($DIFF % 60)) mins</code>
		Changelog: <a href='$SOURCE'> Here </a>
		Last Commit Name: <code>$(git show -s --format=%s)</code>
		Last Commit Hash: <code>$(git rev-parse --short HEAD)</code>"
	else
		telegram-send "Error⚠️ $COMPILER failed to build"
		telegram-send --file $KERNEL_DIR/log.txt
		exit 1
	fi
