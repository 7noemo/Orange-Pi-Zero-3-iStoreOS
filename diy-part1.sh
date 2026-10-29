#!/bin/bash
#
# diy-part1.sh - run before feeds update
#
# Fixes for iStoreOS istoreos-25.12 (OpenWrt 25.12 / kernel 6.12):
# 1. Vendor kmod-uwe5622 (Wi-Fi AW859A) from ImmortalWrt master
# 1b. Adapt uwe5622 cfg80211_ops to mac80211 backports-6.18 (set_wiphy_params
#     gained the radio_idx argument; ImmortalWrt's older 010 patch is dropped)
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

# --- 2b. cfg80211 API: adapt uwe5622 to mac80211 backports-6.18 (iStoreOS 25.12) ---
# The driver selects its cfg80211_ops variants from LINUX_VERSION_CODE, but the
# struct it must satisfy comes from the mac80211 backports package, not from the
# kernel. iStoreOS 25.12 ships backports-6.18.55, whose cfg80211_ops use the
# net_device based station/key callbacks and `set_wiphy_params(wiphy, int radio_idx,
# u32 changed)`. The kernel is 6.12, so:
#   * the net_device variants are picked up automatically (>= 6.1 branches), but
#   * set_wiphy_params still resolves to the pre-6.17 `(wiphy, u32)` form -> the
#     build fails with "initialization of 'int (*)(struct wiphy *, int, u32)' from
#     incompatible pointer type".
# ImmortalWrt's own 010 patch forces the *opposite* (older wireless_dev) variants
# for BUILD_OPENWRT builds, which is wrong for backports-6.18, so replace it.
rm -f package/kernel/uwe5622/patches/010-fix-cfg80211-backport.patch
cat > package/kernel/uwe5622/patches/010-backports-cfg80211-api.patch <<'PATCH'
Subject: [PATCH] wifi: uwe5622: use the backports-6.18 set_wiphy_params signature

The cfg80211_ops struct comes from the mac80211 backports package, whose API
may be newer than the kernel the driver is compiled against. backports-6.18
adds the radio_idx argument to set_wiphy_params, so select that variant when
building for OpenWrt.

--- a/unisocwifi/cfg80211.c
+++ b/unisocwifi/cfg80211.c
@@ -2348,7 +2348,7 @@ err:
 	return ret;
 }
 
-#if LINUX_VERSION_CODE >= KERNEL_VERSION(6, 17, 0)
+#if (LINUX_VERSION_CODE >= KERNEL_VERSION(6, 17, 0)) || defined(BUILD_OPENWRT)
 static int sprdwl_cfg80211_set_wiphy_params(struct wiphy *wiphy, int radio_idx, u32 changed)
 #else
 static int sprdwl_cfg80211_set_wiphy_params(struct wiphy *wiphy, u32 changed)
PATCH
echo "[diy-part1] patched uwe5622 for backports-6.18 cfg80211 API"

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
