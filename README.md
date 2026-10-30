# Orange Pi Zero 3 iStoreOS

[![Build iStoreOS Zero 3](https://github.com/7noemo/Orange-Pi-Zero-3-iStoreOS/actions/workflows/build-istoreos-zero3.yml/badge.svg)](https://github.com/7noemo/Orange-Pi-Zero-3-iStoreOS/actions/workflows/build-istoreos-zero3.yml)

为 **香橙派 Orange Pi Zero 3（全志 H618）** 编译 [iStoreOS](https://github.com/istoreos/istoreos) 固件的 GitHub Actions 云构建仓库。

> ⚠️ 试水项目：iStoreOS 官方不覆盖香橙派 Zero 3 的 Wi-Fi（AW859A / UWE5622），本仓库通过 vendor ImmortalWrt 的 `kmod-uwe5622` 驱动包 + armbian 固件文件实现开箱 Wi-Fi。配套的原生 OpenWrt 版本见 [Orange-Pi-Zero-3-Openwrt](https://github.com/7noemo/Orange-Pi-Zero-3-Openwrt)。
> 历史：首个构建基于 istoreos-24.10（run 40813865211），后切换到官方默认分支 istoreos-25.12。

## 特性

- 基于 iStoreOS `istoreos-25.12` 分支（OpenWrt 25.12 / 内核 6.12，官方默认分支）
- **iStore 应用商店、快捷向导、中文界面**：iStoreOS 原生内置
- **AW859A Wi-Fi**：`kmod-uwe5622`（ImmortalWrt 驱动包）+ `uwe5622-firmware`（sparse-checkout armbian/firmware）
- Docker / Docker Compose / luci-app-dockerman
- htop / iperf3 / ttyd / UPnP / 网络唤醒
- rootfs 分区 512 MiB（容纳 Docker、iStore 等组件）
- Release note 自动做 manifest 校验（Wi-Fi 驱动、商店等关键包确认在镜像内）

## 固件下载

前往 **[Releases](https://github.com/7noemo/Orange-Pi-Zero-3-iStoreOS/releases)** 下载（推荐 squashfs 版）：

- `istoreos-sunxi-cortexa53-xunlong_orangepi-zero3-squashfs-sdcard.img.gz` —— squashfs + overlay，可恢复出厂，**推荐**
- `istoreos-sunxi-cortexa53-xunlong_orangepi-zero3-ext4-sdcard.img.gz` —— ext4 直写，适合想随便改系统文件的人

解压后刷入 TF 卡即可（8 GB 以上）。

## 刷机

```bash
gunzip istoreos-*.img.gz
# macOS / Linux
dd if=istoreos-*.img of=/dev/sdX bs=4M conv=fsync
```

默认 IP：`192.168.100.1`（iStoreOS 默认网段）。

## 构建状态

手动触发：Actions → Build iStoreOS Zero 3 → Run workflow。

首个成功构建：[2026.10.30-0842](https://github.com/7noemo/Orange-Pi-Zero-3-iStoreOS/releases/tag/2026.10.30-0842)
（istoreos-25.12 / 内核 6.12.112，8 个关键包 manifest 校验全部通过）。

### 已趟过的坑（供同样给 H618 板子带 Wi-Fi 的人参考）

- feeds `refresh_config` 会跑 `make defconfig`，seed .config 必须在 **feeds install 之后**再载入，否则商店/quickstart/dockerd 的开关被静默丢弃
- apk 打包不接受 `PKG_VERSION` 里的 `-`（`2026-10` → `2026.10`）
- 内核 6.12 带 `CONFIG_WERROR`：uwe5622 驱动对 backports-6.18 的 cfg80211 API 适配（`set_wiphy_params` 多了 radio_idx 参数）+ 3 处 VLA 改 `sizeof` 定长 + 模块级 `-Wno-error`
- 默认 rootfs 104 MiB 装不下 docker + iStore，需调大 `CONFIG_TARGET_ROOTFS_PARTSIZE`
