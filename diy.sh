#!/bin/bash

# ========== 全局修复 Aurora 依赖 & 解决 dnsmasq 冲突 ==========
echo "===== 修复主题依赖与 dnsmasq 冲突 ====="

# 1. 清理可能残留的 Aurora 源码目录
rm -rf package/feeds/luci/luci-theme-aurora
rm -rf package/feeds/luci/luci-app-aurora-config
rm -rf package/luci-theme-aurora
rm -rf package/luci-app-aurora-config

# 2. 全局修改所有 Makefile，把 aurora 替换成 argon
find ./ -name "Makefile" -type f -exec sed -i 's/luci-theme-aurora/luci-theme-argon/g' {} + 2>/dev/null
find ./ -name "Makefile" -type f -exec sed -i 's/luci-app-aurora-config/luci-app-argon-config/g' {} + 2>/dev/null

# 3. 强制修改 .config，确保彻底移除 aurora
sed -i 's/CONFIG_PACKAGE_luci-theme-aurora=y/# CONFIG_PACKAGE_luci-theme-aurora is not set/g' .config
sed -i 's/CONFIG_PACKAGE_luci-app-aurora-config=y/# CONFIG_PACKAGE_luci-app-aurora-config is not set/g' .config
sed -i 's/# CONFIG_PACKAGE_luci-theme-argon is not set/CONFIG_PACKAGE_luci-theme-argon=y/g' .config
sed -i 's/# CONFIG_PACKAGE_luci-app-argon-config is not set/CONFIG_PACKAGE_luci-app-argon-config=y/g' .config

# 4. 解决 dnsmasq 冲突
sed -i 's/CONFIG_PACKAGE_dnsmasq=y/# CONFIG_PACKAGE_dnsmasq is not set/g' .config
sed -i 's/# CONFIG_PACKAGE_dnsmasq-full is not set/CONFIG_PACKAGE_dnsmasq-full=y/g' .config

echo "✅ 主题与 dnsmasq 冲突修复完成，只保留 Argon"

# ========== 修复 kmod-oaf 循环依赖（仅改源码） ==========
echo "===== 修复 kmod-oaf 循环依赖 ====="

# 去除 kmod-oaf 源码里对自己的依赖（+kmod-oaf）
find ./package ./feeds -path "*kmod-oaf*" -name "Makefile" -exec sed -i 's/+kmod-oaf//g' {} + 2>/dev/null

echo "✅ kmod-oaf 源码依赖已修复"

# ========== 切断 quickstart / luci-app-store 拉取磁盘包的依赖 ==========
echo "===== 切断 quickstart / store 磁盘依赖 ====="

# 1. quickstart：切除所有磁盘/RAID/SMART 依赖，保留核心运行时
if [ -f "package/quickstart/Makefile" ]; then
  sed -i 's/+mount-utils//g; s/+block-mount//g; s/+lsblk//g; s/+e2fsprogs//g; s/+parted//g' package/quickstart/Makefile
  sed -i 's/+smartmontools-drivedb//g; s/+smartmontools//g; s/+smartd//g; s/+mdadm//g' package/quickstart/Makefile
  echo "✅ package/quickstart/Makefile 已切除磁盘/RAID/SMART 依赖"
  echo "---- 修改后的 DEPENDS ----"
  grep -n "DEPENDS" package/quickstart/Makefile
fi

# 2. luci-app-store：切除 mount-utils
if [ -f "package/luci-app-store/Makefile" ]; then
  sed -i 's/+mount-utils//g' package/luci-app-store/Makefile
  echo "✅ package/luci-app-store/Makefile 已切除 mount-utils"
  echo "---- 修改后的 LUCI_DEPENDS ----"
  grep -n "LUCI_DEPENDS" package/luci-app-store/Makefile
fi

# 3. 清理上次打补丁失败残留的 .rej / .orig 文件
find package/quickstart package/luci-app-quickstart package/luci-app-store \
     -name "*.rej" -delete 2>/dev/null
find package/quickstart package/luci-app-quickstart package/luci-app-store \
     -name "*.orig" -delete 2>/dev/null
echo "✅ 清理 .rej / .orig 补丁残留文件完成"

echo "===== quickstart / store 磁盘依赖切断完成 ====="

# ========== 默认启用 Argon 主题 ==========
mkdir -p package/base-files/files/etc/uci-defaults
cat > package/base-files/files/etc/uci-defaults/99-set-argon << 'EOT'
if [ -d "/www/luci-static/argon" ]; then
    uci set luci.main.mediaurlbase='/luci-static/argon'
    uci commit luci
fi
exit 0
EOT
chmod +x package/base-files/files/etc/uci-defaults/99-set-argon

# ========== 吉林大学镜像站 ==========
mkdir -p package/base-files/files/etc/opkg
cat > package/base-files/files/etc/opkg/distfeeds.conf << 'EOF'
src/gz immortalwrt_core https://mirrors.jlu.edu.cn/immortalwrt/releases/24.10.6/targets/mediatek/filogic/packages
src/gz immortalwrt_base https://mirrors.jlu.edu.cn/immortalwrt/releases/24.10.6/packages/aarch64_cortex-a53/base
src/gz immortalwrt_luci https://mirrors.jlu.edu.cn/immortalwrt/releases/24.10.6/packages/aarch64_cortex-a53/luci
src/gz immortalwrt_packages https://mirrors.jlu.edu.cn/immortalwrt/releases/24.10.6/packages/aarch64_cortex-a53/packages
src/gz immortalwrt_routing https://mirrors.jlu.edu.cn/immortalwrt/releases/24.10.6/packages/aarch64_cortex-a53/routing
src/gz immortalwrt_telephony https://mirrors.jlu.edu.cn/immortalwrt/releases/24.10.6/packages/aarch64_cortex-a53/telephony
EOF

# ========== 默认启用 ZRAM（128MB + zstd） ==========
cat > package/base-files/files/etc/uci-defaults/98-enable-zram << 'EOT'
uci set system.@system[0].zram_size_mb='128'
uci set system.@system[0].zram_comp_algo='zstd'
uci commit system
exit 0
EOT
chmod +x package/base-files/files/etc/uci-defaults/98-enable-zram

# ========== 内存优化内核参数 ==========
mkdir -p package/base-files/files/etc/sysctl.d
cat > package/base-files/files/etc/sysctl.d/99-memory-optimize.conf << 'EOF'
vm.vfs_cache_pressure = 200
vm.min_free_kbytes = 8192
vm.swappiness = 80
EOF

# ========== 精简 MTK 默认包 & 彻底删除 USB/磁盘分区 ==========
echo "=== 精简 MTK 默认包 ==="

# 1) 从 target/linux/mediatek/Makefile 删除 USB 相关
if [ -f "target/linux/mediatek/Makefile" ]; then
  sed -i 's/kmod-usb2 //g; s/kmod-usb3 //g; s/kmod-usb-net-rndis //g; s/usbutils//g; s/kmod-fs-btrfs //g' \
    target/linux/mediatek/Makefile
  echo "--- Makefile 修改后 ---"
  sed -n '14,23p' target/linux/mediatek/Makefile
else
  echo "⚠️ 未找到 target/linux/mediatek/Makefile"
fi

# 2) 从 target.mk 删除 safexcel
if [ -f "target/linux/mediatek/filogic/target.mk" ]; then
  sed -i 's/kmod-crypto-hw-safexcel //g' \
    target/linux/mediatek/filogic/target.mk
  echo "--- target.mk 修改后 ---"
  cat target/linux/mediatek/filogic/target.mk
else
  echo "⚠️ 未找到 target/linux/mediatek/filogic/target.mk"
fi

# 3) 从 mt7981.mk 中删除 USB/存储/磁盘分区默认包（关键步骤）
if [ -f "target/linux/mediatek/image/mt7981.mk" ]; then
  sed -i 's/kmod-usb-core //g; s/kmod-usb2 //g; s/kmod-usb-ohci //g; s/kmod-usb-storage //g; s/kmod-usb-storage-extras //g; s/kmod-usb-storage-uas //g; s/kmod-scsi-core //g; s/kmod-fs-ext4 //g; s/kmod-fs-vfat //g; s/kmod-fs-exfat //g; s/kmod-fs-ntfs3 //g; s/kmod-fs-btrfs //g; s/kmod-fs-autofs4 //g; s/kmod-nls-cp437 //g; s/kmod-nls-iso8859-1 //g; s/kmod-nls-utf8 //g; s/automount //g; s/ntfs3-mount //g; s/block-mount //g; s/blockd //g; s/blockdev //g; s/e2fsprogs //g; s/parted //g; s/lsblk //g; s/mount-utils //g; s/blkid //g; s/fdisk //g' \
    target/linux/mediatek/image/mt7981.mk
  echo "--- mt7981.mk 修改后 ---"
  cat target/linux/mediatek/image/mt7981.mk
else
  echo "⚠️ 未找到 target/linux/mediatek/image/mt7981.mk"
fi

# 4) 全局搜索删除（覆盖所有可能存放默认包的文件）
find target/linux/mediatek -name "Makefile" -o -name "*.mk" | while read f; do
  sed -i 's/kmod-usb-core //g; s/kmod-usb-storage //g; s/kmod-scsi-core //g; s/kmod-fs-ext4 //g; s/kmod-fs-vfat //g; s/kmod-fs-exfat //g; s/kmod-fs-ntfs3 //g; s/kmod-fs-btrfs //g; s/automount //g; s/ntfs3-mount //g; s/parted //g; s/fdisk //g; s/e2fsprogs //g; s/lsblk //g; s/mount-utils //g; s/blkid //g; s/blockdev //g' "$f"
done
echo "✅ USB/磁盘分区包已从目标源码中彻底删除"

# ========== 完美伪装 vermagic ==========
echo "=== 完美伪装 vermagic ==="

WRT_ROOT="${GITHUB_WORKSPACE}/wrt"
cd "$WRT_ROOT" || cd /mnt/build_wrt || exit 1

echo "a8b93917f464536104594f27d870028d" > "$WRT_ROOT/vermagic"
echo "--- 已创建 $WRT_ROOT/vermagic ---"
cat "$WRT_ROOT/vermagic"

KDM="$WRT_ROOT/include/kernel-defaults.mk"
if [ ! -f "$KDM" ]; then
  echo "❌ 未找到 $KDM"
  exit 1
fi

if grep -q 'cp $(TOPDIR)/vermagic' "$KDM"; then
  echo "⚠️ 已存在 cp 行，跳过"
else
  TMPFILE=$(mktemp)
  while IFS= read -r line; do
    echo "$line" >> "$TMPFILE"
    if echo "$line" | grep -q '\.config\.set.*MKHASH.*\.vermagic'; then
      printf '\tcp $(TOPDIR)/vermagic $(LINUX_DIR)/.vermagic\n' >> "$TMPFILE"
    fi
  done < "$KDM"
  mv "$TMPFILE" "$KDM"
  echo "✅ kernel-defaults.mk 已修改"
fi

echo "--- 修改后 128-134 行 ---"
sed -n '128,134p' "$KDM"
if grep -q 'cp $(TOPDIR)/vermagic' "$KDM"; then
  echo "✅ cp 行已成功插入"
else
  echo "❌ cp 行插入失败！"
  exit 1
fi

echo "=== vermagic 完美伪装完成 ==="
echo "=== MTK 默认包精简完成 ==="
echo "✅ diy.sh 执行完成"
