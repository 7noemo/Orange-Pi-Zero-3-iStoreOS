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

# --- 2c. VLA reply buffers (-Werror=vla under CONFIG_WERROR) ---
# The sunxi 6.12 kernel is built with CONFIG_WERROR. uwe5622 still sized three
# reply buffers with a runtime u16 (u8 r_buf[r_len]), which gcc treats as a
# variable-length array:
#   cmdevt.c:3639: error: ISO C90 forbids variable length array 'r_buf' [-Werror=vla]
# Port the upstream fixes (armbian/uwe5622 d6a378a + fa9d1a6) so the arrays use
# the sizeof expression the lengths are computed from. Also keep any remaining
# driver warning non-fatal, otherwise one warning aborts a 60 minute build.
cat > package/kernel/uwe5622/patches/015-fix-wvla-reply-buffers.patch <<'PATCH'
Subject: [PATCH] unisocwifi: size the reply buffers with sizeof (-Wvla)

sprdwl_set_packet_offload(), sprdwl_vendor_get_llstat_handler() and
sprdwl_vendor_clr_llstat_handler() size r_buf[] by a u16 that only ever holds
a sizeof value, so gcc sees a variable-length array and kernels built with
CONFIG_WERROR fail with -Werror=vla.

Use the sizeof expression as the array size; r_len keeps its role as the
in/out reply length.

Ported from armbian/uwe5622 d6a378a and fa9d1a6.

--- a/unisocwifi/cmdevt.c
+++ b/unisocwifi/cmdevt.c
@@ -3630,7 +3630,7 @@ int sprdwl_set_packet_offload(struct sprdwl_priv *priv, u8 vif_ctx_id,
 	struct sprdwl_cmd_packet_offload *p;
 	struct sprdwl_cmd_packet_offload *packet = NULL;
 	u16 r_len = sizeof(*packet);
-	u8 r_buf[r_len];
+	u8 r_buf[sizeof(*packet)];
 
 	msg = sprdwl_cmd_getbuf(priv, sizeof(*p) + len, vif_ctx_id,
 				SPRDWL_HEAD_RSP, WIFI_CMD_PACKET_OFFLOAD);
--- a/unisocwifi/vendor.c
+++ b/unisocwifi/vendor.c
@@ -471,7 +471,7 @@ static int sprdwl_vendor_get_llstat_handler(struct wiphy *wiphy,
 	struct wifi_iface_stat *iface_st;
 	struct sprdwl_llstat_radio *dif_radio;
 	u16 r_len = sizeof(*llst);
-	u8 r_buf[r_len], ret, i;
+	u8 r_buf[sizeof(*llst)], ret, i;
 	u32 reply_radio_length, reply_iface_length;
 
 	struct sprdwl_priv *priv = wiphy_priv(wiphy);
@@ -593,7 +593,7 @@ static int sprdwl_vendor_clr_llstat_handler(struct wiphy *wiphy,
 	struct nlattr *tb[SPRDWL_LL_STATS_CLR_MAX + 1];
 	u32 *stats_clear_rsp_mask, stats_clear_req_mask = 0;
 	u16 r_len = sizeof(*stats_clear_rsp_mask);
-	u8 r_buf[r_len];
+	u8 r_buf[sizeof(*stats_clear_rsp_mask)];
 	u32 reply_length, ret, err;
 
 	struct sprdwl_priv *priv = wiphy_priv(wiphy);
PATCH
# ccflags-y is applied after KBUILD_CFLAGS (scripts/Makefile.lib), so this
# overrides the kernel's -Werror for this package only.
for mk in package/kernel/uwe5622/unisocwifi/Makefile \
          package/kernel/uwe5622/unisocwcn/Makefile; do
  { echo 'ccflags-y += -Wno-error'; cat "$mk"; } > "$mk.new" && mv "$mk.new" "$mk"
done
echo "[diy-part1] patched uwe5622 VLA reply buffers"

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
