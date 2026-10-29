# Orange Pi Zero 3 iStoreOS

为 **香橙派 Orange Pi Zero 3（全志 H618）** 编译 [iStoreOS](https://github.com/istoreos/istoreos) 固件的 GitHub Actions 云构建仓库。

> ⚠️ 试水项目：iStoreOS 官方不覆盖香橙派 Zero 3 的 Wi-Fi（AW859A / UWE5622），本仓库通过 vendor ImmortalWrt 的 `kmod-uwe5622` 驱动包 + armbian 固件文件实现开箱 Wi-Fi。配套的原生 OpenWrt 版本见 [Orange-Pi-Zero-3-Openwrt](https://github.com/7noemo/Orange-Pi-Zero-3-Openwrt)。
> 历史：首个构建基于 istoreos-24.10（run 40813865211），后切换到官方默认分支 istoreos-25.12。

## 特性

- 基于 iStoreOS `istoreos-25.12` 分支（OpenWrt 25.12 / 内核 6.12，官方默认分支）
- **iStore 应用商店、快捷向导、中文界面**：iStoreOS 原生内置
- **AW859A Wi-Fi**：`kmod-uwe5622`（ImmortalWrt 驱动包）+ `uwe5622-firmware`（sparse-checkout armbian/firmware）
- Docker / Docker Compose / luci-app-dockerman
- htop / iperf3 / ttyd / UPnP / 网络唤醒
- Release note 自动做 manifest 校验（Wi-Fi 驱动、商店等关键包确认在镜像内）

## 固件下载

前往 **Releases** 下载 `istoreos-*-xunlong_orangepi-zero3-squashfs-combined.img.gz`，解压后刷入 TF 卡即可。

## 刷机

```bash
gunzip istoreos-*.img.gz
# macOS / Linux
dd if=istoreos-*.img of=/dev/sdX bs=4M conv=fsync
```

默认 IP：`192.168.100.1`（iStoreOS 默认网段）。

## 构建状态

手动触发：Actions → Build iStoreOS Zero 3 → Run workflow。
