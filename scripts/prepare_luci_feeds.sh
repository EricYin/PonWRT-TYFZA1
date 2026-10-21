#!/bin/sh
# SPDX-License-Identifier: GPL-2.0-only
# 合并版 = 上游 v0.7.0-alpha 的 Argon git 管理逻辑 + feeds update -a
# （合入上游 b8b0067 时，直接用本文件覆盖 scripts/prepare_luci_feeds.sh）
set -eu
P=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
TREE=${1:-$P/sources/openwrt}
TREE=$(realpath "$TREE")
PACKAGES=$(sed -n 's/^CONFIG_PACKAGE_\([^=]*\)=[ym]$/\1/p' "$TREE/.config")
cp "$P/configs/feeds.conf" "$TREE/feeds.conf"
cd "$TREE"
if [ -n "${TYFZA1_PROXY:-}" ]; then
    export http_proxy=$TYFZA1_PROXY https_proxy=$TYFZA1_PROXY
fi
# Argon is a single-package repository, not a feed containing package folders.
# Its directory must also be named luci-theme-argon for luci.mk to name the package.
ARGON="$TREE/feeds/luci-theme-argon"
set -- $(python3 -c 'import json,sys; s=json.load(open(sys.argv[1]))["luci_theme_argon"]; print(s["url"],s["commit"])' "$P/port/sources.lock.json")
mkdir -p "$TREE/feeds" "$TREE/package"
if [ ! -d "$ARGON/.git" ]; then
    git init "$ARGON"
fi
if ! git -C "$ARGON" diff --quiet || ! git -C "$ARGON" diff --cached --quiet; then
    echo "Argon checkout has local changes; refusing to replace them" >&2
    exit 1
fi
if [ "$(git -C "$ARGON" rev-parse --verify HEAD 2>/dev/null || true)" != "$2" ]; then
    git -C "$ARGON" fetch --depth=1 "$1" "$2"
    git -C "$ARGON" checkout --detach "$2"
fi
if [ -e "$TREE/package/luci-theme-argon" ] && [ ! -L "$TREE/package/luci-theme-argon" ]; then
    echo "package/luci-theme-argon already exists and is not a managed symlink" >&2
    exit 1
fi
ln -sfn "$ARGON" "$TREE/package/luci-theme-argon"
# dl12345/mwan3（nftables 原生移植版）：仓库根即包根，OpenWrt 的 feed 扫描器
# （include/scan.mk 的 FILELIST sed 管道）只能清洗"目录/包名/Makefile"形式的嵌套路径，
# 根级包会产生毒化条目导致索引失败、整个 feed 被忽略。因此克隆后重嵌套进子目录，
# 由 feeds.conf 的 src-link mwan3nft vendor/mwan3nft 引入（置于 packages 之前覆盖官方版）。
# 暂存到 openwrt 树之外，避免污染被 make 扫描的目录；src-link 的符号链接目标
# 相对于链接所在目录解析，故这里把 feeds.conf 里的行动态改写为绝对路径。
MWAN3NFT=$(dirname "$TREE")/vendor/mwan3nft
rm -rf "$MWAN3NFT"
mkdir -p "$MWAN3NFT"
git clone --depth 1 --branch openwrt-25.12 https://github.com/dl12345/mwan3.git "$MWAN3NFT/mwan3"
rm -rf "$MWAN3NFT/mwan3/.git" "$MWAN3NFT/mwan3/.github"
sed -i "s|^src-link mwan3nft .*|src-link mwan3nft $MWAN3NFT|" "$TREE/feeds.conf"
# 更新全部 feed（mwan3nft、passwall、passwall_packages 等，必须为 -a）
./scripts/feeds update -a
# 上游 v0.8.0-beta：应用 LuCI 补丁
sh "$P/port/scripts/apply-luci-patches.sh" "$TREE"
printf '%s\n' "$PACKAGES" | xargs ./scripts/feeds install cgi-io luasrcdiet luci
# Existing build trees retain .config; select the new default there as well.
sed -i '/^CONFIG_PACKAGE_luci-theme-argon=/d; /^# CONFIG_PACKAGE_luci-theme-argon is not set$/d; /^CONFIG_PACKAGE_luci-i18n-argon-config-zh-cn=/d; /^# CONFIG_PACKAGE_luci-i18n-argon-config-zh-cn is not set$/d' .config
printf '%s\n' 'CONFIG_PACKAGE_luci-theme-argon=y' 'CONFIG_PACKAGE_luci-i18n-argon-config-zh-cn=y' >> .config
# Each LuCI app owns its translation catalog; base and theme catalogs do not cover it.
sed -i '/^CONFIG_LUCI_LANG_zh_Hans=/d; /^# CONFIG_LUCI_LANG_zh_Hans is not set$/d' .config
printf '%s\n' 'CONFIG_LUCI_LANG_zh_Hans=y' >> .config
