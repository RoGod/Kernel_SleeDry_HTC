#!/bin/bash
#
clear

start_time=`date +'%d/%m/%y %H:%M:%S'`

echo "#################### ELIMINANDO COMPILACIONES ANTERIORES ####################"

./clean.sh > /dev/null 2>&1
./clean-junk.sh > /dev/null 2>&1

if [ -e boot.img ]; then
        rm boot.img
fi;

if [ -e compile.log ]; then
        rm compile.log
fi;

if [ -e initrd.cpio ]; then
        rm initrd.cpio
fi;

if [ -e initrd.cpio.gz ]; then
        rm initrd.cpio.gz
fi;

make distclean
make clean && make mrproper
rm Module.symvers > /dev/null 2>&1

echo "#################### PREPARANDO NUEVO ENTORNO ####################"

if [ "${1}" != "" ]; then
	export KERNELDIR=`readlink -f ${1}`
else
	export KERNELDIR=`readlink -f .`
fi;

export RAMFS_SOURCE=`readlink -f $KERNELDIR/initrd`
export BOOT=`readlink -f $KERNELDIR/SleeDry`
NR_CPUS=$(expr `grep processor /proc/cpuinfo | wc -l` + 1)

RAMFS_TMP="/home/rogod/Kernel/tmp/ramfs-source-htc"
TOOLCHAIN="/home/rogod/android-ndk-r10b/toolchains/arm-linux-androideabi-4.6/prebuilt/linux-x86_64/bin/arm-linux-androideabi-"
export KERNEL_VERSION="Mega"
export REVISION="V"
export KBUILD_BUILD_VERSION="1"

echo "#################### VERIFICANDO RUTAS DEL COMPILADOR ####################"

echo "toolchain = ${TOOLCHAIN}"
echo "kerneldir = ${KERNELDIR}"
echo "ramfs_source = ${RAMFS_SOURCE}"
echo "ramfs_tmp = ${RAMFS_TMP}"
echo "nr_cpus = ${NR_CPUS}"

echo "#################### APLICANDO PERMISOS AL INITRD ####################"

chmod 644 $RAMFS_SOURCE/*.rc
chmod 750 $RAMFS_SOURCE/init*
chmod 640 $RAMFS_SOURCE/fstab*
chmod 644 $RAMFS_SOURCE/default.prop
chmod 771 $RAMFS_SOURCE/data
chmod 755 $RAMFS_SOURCE/dev
chmod 755 $RAMFS_SOURCE/proc
chmod 750 $RAMFS_SOURCE/sbin
chmod 750 $RAMFS_SOURCE/sbin/*
chmod 755 $RAMFS_SOURCE/sys
chmod 755 $RAMFS_SOURCE/system

find . -type f -name '*.h' -exec chmod 644 {} \;
find . -type f -name '*.c' -exec chmod 644 {} \;
find . -type f -name '*.py' -exec chmod 755 {} \;
find . -type f -name '*.sh' -exec chmod 755 {} \;
find . -type f -name '*.pl' -exec chmod 755 {} \;

echo "#################### ELIMINANDO BUILD ANTERIOR ####################"

make ARCH=arm CROSS_COMPILE=$TOOLCHAIN -j${NR_CPUS} mrproper
make ARCH=arm CROSS_COMPILE=$TOOLCHAIN -j${NR_CPUS} clean

echo "#################### COMPILAR KERNEL ####################"

make ARCH=arm CROSS_COMPILE=$TOOLCHAIN rogod_defconfig

make -j${NR_CPUS} ARCH=arm CROSS_COMPILE=$TOOLCHAIN || exit 1

make -j${NR_CPUS} ARCH=arm CROSS_COMPILE=$TOOLCHAIN modules || exit 1

echo "#################### COMPILAR WIRELESS MODULES ####################"

make -C drivers/net/wireless/compat-wireless_R5.SP2.03 KLIB=`pwd` KLIB_BUILD=`pwd` clean -j${NR_CPUS}

make -C drivers/net/wireless/compat-wireless_R5.SP2.03 KLIB=`pwd` KLIB_BUILD=`pwd` -j${NR_CPUS}

echo "#################### CORRIGIENDO RAMFS_TMP ####################"

if [ -d $RAMFS_TMP ]; then
	rm -rf $RAMFS_TMP > /dev/null 2>&1
	rm -rf $RAMFS_TMPcpio > /dev/null 2>&1
	rm -rf $RAMFS_TMPcpio.gz > /dev/null 2>&1
else
	mkdir $RAMFS_TMP
	chown root:root $RAMFS_TMP
	chmod 777 $RAMFS_TMP
fi;

rm -rf $KERNELDIR/*.cpio > /dev/null 2>&1
rm -rf $KERNELDIR/*.cpio.gz > /dev/null 2>&1

echo "#################### COPIANDO RAMFS_SOURCE A RAMFS_TMP ####################"

cp -ax $RAMFS_SOURCE $RAMFS_TMP

echo "##################### BORRANDO EMPY Y ARCHIVOS INNECESARIOS ####################"

find $RAMFS_TMP -name EMPTY_DIRECTORY -exec rm -rf {} \;
find $RAMFS_TMP -name .EMPTY_DIRECTORY -exec rm -rf {} \;
find $BOOT -name EMPTY_DIRECTORY -exec rm -rf {} \;
find $BOOT -name .EMPTY_DIRECTORY -exec rm -rf {} \;
find $RAMFS_TMP -name .git -exec rm -rf {} \;
rm -rf $RAMFS_TMP/tmp/* > /dev/null 2>&1
rm -rf $RAMFS_TMP/.hg > /dev/null 2>&1

echo "##################### CREANDO RUTA PARA MODULES ####################"

mkdir -p $BOOT/zip/system/lib/modules

echo "###################### COPIANDO MODULES A RUTA ####################"

find . -name '*.ko' -exec cp -av {} $BOOT/zip/system/lib/modules/ \;

find $KERNELDIR/arch -type f -name '*.ko' -exec cp -f {} $BOOT/zip/system/lib/modules \;
find $KERNELDIR/crypto -type f -name '*.ko' -exec cp -f {} $BOOT/zip/system/lib/modules \;
find $KERNELDIR/fs -type f -name '*.ko' -exec cp -f {} $BOOT/zip/system/lib/modules \;
find $KERNELDIR/ipc -type f -name '*.ko' -exec cp -f {} $BOOT/zip/system/lib/modules \; 
find $KERNELDIR/net -type f -name '*.ko' -exec cp -f {} $BOOT/zip/system/lib/modules \;
find $KERNELDIR/drivers -type f -name '*.ko' -exec cp -f {} $BOOT/zip/system/lib/modules \;
find $KERNELDIR/drivers/net/wireless/compat-wireless_R5.SP2.03 -type f -name '*.ko' -exec cp -f {} $BOOT/zip/system/lib/modules \;

echo "###################### DANDO PERMISOS A RUTA DE MODULES ####################"

chmod 755 $BOOT/zip/system/lib
chmod 755 $BOOT/zip/system/lib/modules
chmod 644 $BOOT/zip/system/lib/modules/*

echo "####################### CREANDO BUSYBOX EN RAMFS_TMP  ########################"

./busy.sh > /dev/null 2>&1

echo "#################### COMPRIMIENDO RAMFS_TMP A .CPIO ####################"

cd $RAMFS_TMP
find . | fakeroot cpio -o -H newc > $RAMFS_TMP.cpio 2>/dev/null
ls -lh $RAMFS_TMP.cpio
gzip -9 -f $RAMFS_TMP.cpio

echo "#################### CREANDO BOOT.IMG ####################"

cd $KERNELDIR
./mkbootimg --kernel $KERNELDIR/arch/arm/boot/zImage --ramdisk $RAMFS_TMP.cpio.gz --pagesize 2048 --ramdiskaddr 0x0049C4F0 -o $KERNELDIR/boot.img

echo "#################### PREPARANDO EL FLASHEABLE ####################"

# ELIMINANDO FLASHEABLE ANTIGUO
rm -f $BOOT/zip/*.zip > /dev/null 2>&1

# COPIANDO BOOT.IMG
cp boot.img $BOOT/zip
cp boot.img $BOOT

# COMPRIMIENDO
cd $BOOT/zip
zip -ry -9 "$KERNEL_VERSION-$REVISION$KBUILD_BUILD_VERSION.zip" . -x "*.zip"

cd ../..

echo "#################### ELIMINANDO RESTOS ####################"

find "$KERNELDIR" -type f -iname "*.ko" | while read line; do
	rm -f "$line"
done

rm -f $BOOT/zip/boot.img > /dev/null 2>&1
rm -rf $BOOT/zip/system > /dev/null 2>&1
rm -f $KERNELDIR/arch/arm/boot/*.dtb > /dev/null 2>&1
rm -f $KERNELDIR/arch/arm/boot/*.cmd > /dev/null 2>&1
rm -rf $KERNELDIR/arch/arm/boot/Image > /dev/null 2>&1
rm -rf $KERNELDIR/arch/arm/boot/zImage > /dev/null 2>&1
rm -f $KERNELDIR/boot.img > /dev/null 2>&1
rm -rf $RAMFS_TMP/* > /dev/null 2>&1
cd $RAMFS_TMP > /dev/null 2>&1
cd ..
rm ramfs-source-htc.cpio.gz > /dev/null 2>&1
rm /home/rogod/Kernel/tmp/ramfs-source-htc.cpio.gz > /dev/null 2>&1

echo "#################### TERMINADO ####################"