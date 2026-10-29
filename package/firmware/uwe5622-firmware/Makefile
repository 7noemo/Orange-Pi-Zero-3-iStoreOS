# SPDX-License-Identifier: GPL-2.0-only
#
# UNISOC UWE5622 firmware for AW859A (Orange Pi Zero 3 onboard Wi-Fi)
# The two binary files are fetched by diy-part1.sh (sparse checkout of
# armbian/firmware, uwe5622 dir only) before feeds update.

include $(TOPDIR)/rules.mk

PKG_NAME:=uwe5622-firmware
PKG_VERSION:=2026-10
PKG_RELEASE:=1

include $(INCLUDE_DIR)/package.mk

define Package/uwe5622-firmware
  SECTION:=firmware
  CATEGORY:=Firmware
  TITLE:=UNISOC UWE5622 firmware (AW859A)
  DEPENDS:=@TARGET_sunxi
  PKGARCH:=all
endef

define Package/uwe5622-firmware/description
  Firmware files (wcnmodem.bin, wifi_2355b001_1ant.ini) for the Unisoc
  UWE5622 / AW859A wireless chipset, required by kmod-uwe5622.
endef

define Build/Prepare
	mkdir -p $(PKG_BUILD_DIR)
	$(CP) ./wcnmodem.bin $(PKG_BUILD_DIR)/
	$(CP) ./wifi_2355b001_1ant.ini $(PKG_BUILD_DIR)/
endef

define Build/Compile
	true
endef

define Package/uwe5622-firmware/install
	$(INSTALL_DIR) $(1)/lib/firmware/uwe5622
	$(INSTALL_DATA) $(PKG_BUILD_DIR)/wcnmodem.bin $(1)/lib/firmware/uwe5622/
	$(INSTALL_DATA) $(PKG_BUILD_DIR)/wifi_2355b001_1ant.ini $(1)/lib/firmware/uwe5622/
endef

$(eval $(call BuildPackage,uwe5622-firmware))
