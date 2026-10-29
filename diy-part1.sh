#!/bin/bash
#
# diy-part1.sh - run before feeds update
#
# Fixes for iStoreOS istoreos-25.12 (OpenWrt 25.12 / kernel 6.12):
# 1. Vendor kmod-uwe5622 (Wi-Fi AW859A) from ImmortalWrt master
# 2. Vendor mdadm (missing from jjm2473 packages 25.12 fork; needed by quickstart)
# 3. Vendor curl (dropped from jjm2473 packages 25.12 fork; needed by
#    luci-app-store / luci-app-ota / opkg)
# 4. Copy local package tree (uwe5622-firmware Makefile lives in the build repo)
# 5. Fetch UWE5622 firmware files (sparse checkout of armbian/firmware)
# 6. Append linkease feeds (official quickstart source)

set -e

# --- 1. UWE5622 kernel driver package ---
mkdir -p package/kernel
git clone --depth 1 https://github.com/immortalwrt/immortalwrt.git /tmp/immwrt-master
cp -r /tmp/immwrt-master/package/kernel/uwe5622 package/kernel/
# --- 2. mdadm (quickstart dependency) ---
rm -rf package/utils/mdadm
cp -r /tmp/immwrt-master/package/utils/mdadm package/utils/
rm -rf /tmp/immwrt-master
echo "[diy-part1] vendored uwe5622 + mdadm"

# --- 3. curl (luci-app-store / opkg dependency, dropped in 25.12 fork) ---
git clone --depth 1 --filter=blob:none https://github.com/openwrt/packages.git /tmp/owrt-pkgs
rm -rf package/vendor/curl
mkdir -p package/vendor
cp -r /tmp/owrt-pkgs/net/curl package/vendor/curl
rm -rf /tmp/owrt-pkgs
echo "[diy-part1] vendored curl"

# --- 4. local package tree (firmware package Makefile from build repo) ---
mkdir -p package/firmware
rm -rf package/firmware/uwe5622-firmware
cp -r "$GITHUB_WORKSPACE/package/firmware/uwe5622-firmware" package/firmware/

# --- 5. UWE5622 firmware files (only the uwe5622 dir) ---
git clone --depth 1 --filter=blob:none --sparse https://github.com/armbian/firmware.git /tmp/armbian-fw
cd /tmp/armbian-fw
git sparse-checkout set uwe5622
cd - >/dev/null
cp /tmp/armbian-fw/uwe5622/wcnmodem.bin package/firmware/uwe5622-firmware/
cp /tmp/armbian-fw/uwe5622/wifi_2355b001_1ant.ini package/firmware/uwe5622-firmware/
rm -rf /tmp/armbian-fw
echo "[diy-part1] fetched uwe5622 firmware files"

# --- 6. linkease feeds (quickstart official source) ---
if ! grep -q "linkease/nas-packages" feeds.conf.default; then
cat >> feeds.conf.default <<'EOF'
# quickstart (newbie wizard) official sources
src-git nas https://github.com/linkease/nas-packages.git;master
src-git nasluci https://github.com/linkease/nas-packages-luci.git;main
EOF
fi
echo "[diy-part1] appended linkease feeds"
