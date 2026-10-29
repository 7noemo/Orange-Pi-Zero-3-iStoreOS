#!/bin/bash
#
# diy-part1.sh - run before feeds update
# 1. Vendor kmod-uwe5622 from ImmortalWrt master (iStoreOS 24.10 does not ship it)
# 2. Fetch UWE5622 firmware files (sparse checkout of armbian/firmware)

set -e

# --- 1. UWE5622 kernel driver package ---
mkdir -p package/kernel
git clone --depth 1 https://github.com/immortalwrt/immortalwrt.git /tmp/immwrt-master
cp -r /tmp/immwrt-master/package/kernel/uwe5622 package/kernel/
rm -rf /tmp/immwrt-master
echo "[diy-part1] vendored package/kernel/uwe5622"

# --- 2. UWE5622 firmware files (only the uwe5622 dir) ---
git clone --depth 1 --filter=blob:none --sparse https://github.com/armbian/firmware.git /tmp/armbian-fw
cd /tmp/armbian-fw
git sparse-checkout set uwe5622
cd - >/dev/null

mkdir -p package/firmware/uwe5622-firmware
cp /tmp/armbian-fw/uwe5622/wcnmodem.bin package/firmware/uwe5622-firmware/
cp /tmp/armbian-fw/uwe5622/wifi_2355b001_1ant.ini package/firmware/uwe5622-firmware/
rm -rf /tmp/armbian-fw
echo "[diy-part1] fetched uwe5622 firmware files"
