#!/bin/sh
# Rebuilds files/<car>/bcmdhd-rtl8811au.ko in Docker (Ubuntu 16.04, gcc 4.9) from public sources.
#   usb-wifi/tools/build-driver.sh <sg2ev|tm23> <output.ko>
# Kernel: a community 3.18.24 Telechips tree, not the car's exact source (Mobis hasn't published
# that). <car>/kernel.config is that car's kernel config resolved against this tree:
#   sg2ev: the car's own config (TCC803X; LPAE and 64-bit DMA addresses), plus <car>/prep.sh;
#   tm23:  the tree's wp_daudioplus_kia_us_defconfig (a plain 32-bit TCC897X kernel) plus
#          CONFIG_BRIDGE_NETFILTER. A driver built with the SG2EV config has the wrong struct urb,
#          scatterlist and resource layouts on a TM23 (tools/check-layout.py shows it).
set -e
CAR=${1:?usage: build-driver.sh <sg2ev|tm23> <output.ko>}
OUT=${2:?usage: build-driver.sh <sg2ev|tm23> <output.ko>}
cd "$(dirname "$0")"
[ -f "$CAR/kernel.config" ] || { echo "no such car: $CAR" >&2; exit 1; }
KERNEL=3402d473aed6a2b82c5d08e0ceafc4a54701a4a0   # C457/android_kernel_telechips_tcc897x
DRIVER=1a819991f5b75e64dfcf922b96a6681f367cbba0   # morrownr/8821au-20210708
docker run --rm -i --platform linux/arm64 -e KERNEL=$KERNEL -e DRIVER=$DRIVER -e CAR="$CAR" \
    -v "$PWD":/in:ro ubuntu:16.04 sh -es > "$OUT" <<'SCRIPT'
exec 3>&1 1>&2
apt-get update -qq
apt-get install -y -qq --no-install-recommends gcc-4.9-arm-linux-gnueabi binutils-arm-linux-gnueabi \
    make bc gcc libc6-dev python curl ca-certificates patch perl >/dev/null
ln -sf /usr/bin/arm-linux-gnueabi-gcc-4.9 /usr/bin/arm-linux-gnueabi-gcc
export ARCH=arm CROSS_COMPILE=arm-linux-gnueabi-
mkdir -p /w/k /w/8821au-20210708
curl -sSL https://codeload.github.com/C457/android_kernel_telechips_tcc897x/tar.gz/$KERNEL | tar xz --strip-components=1 -C /w/k
curl -sSL https://codeload.github.com/morrownr/8821au-20210708/tar.gz/$DRIVER | tar xz --strip-components=1 -C /w/8821au-20210708
cd /w/k
if [ -f /in/$CAR/prep.sh ]; then . /in/$CAR/prep.sh; fi
cp /in/$CAR/kernel.config .config
make olddefconfig >/dev/null 2>&1
make -j6 modules_prepare >/dev/null 2>&1
cd /w/8821au-20210708
patch -p1 -s < /in/driver-changes.patch
make -j6 KSRC=/w/k CONFIG_PLATFORM_AUTODETECT=n CONFIG_RTW_ANDROID=4 CONFIG_LOAD_PHY_PARA_FROM_FILE=n \
    CONFIG_POWER_SAVING=n CONFIG_WIFI_MONITOR=n CONFIG_RTW_LOG_LEVEL=2 \
    KCFLAGS="-DCONFIG_RTW_REGD_SRC=0 -DCONFIG_APPEND_VENDOR_IE_ENABLE -DCONFIG_LITTLE_ENDIAN -DCONFIG_IOCTL_CFG80211 -DRTW_USE_CFG80211_STA_EVENT" \
    modules >/dev/null 2>&1
arm-linux-gnueabi-strip --strip-debug -o /tmp/out.ko bcmdhd.ko
cat /tmp/out.ko >&3
SCRIPT
md5 -q "$OUT" 2>/dev/null || md5sum "$OUT"
