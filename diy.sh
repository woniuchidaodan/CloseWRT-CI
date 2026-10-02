#!/bin/bash

# ========== 全局修复 Aurora 依赖 & 解决循环依赖 ==========
echo "===== 修复主题依赖与循环依赖冲突 ====="

# 1. 清理可能残留的 Aurora 源码目录
rm -rf package/feeds/luci/luci-theme-aurora
rm -rf package/feeds/luci/luci-app-aurora-config
rm -rf package/luci-theme-aurora
rm -rf package/luci-app-aurora-config

# 2. 全局修改所有 Makefile，把 aurora 依赖强制替换为 argon（防止 luci-light / luci-nginx 等底层包报错）
find ./ -name "Makefile" -type f -exec sed -i 's/luci-theme-aurora/luci-theme-argon/g' {} + 2>/dev/null
find ./ -name "Makefile" -type f -exec sed -i 's/luci-app-aurora-config/luci-app-argon-config/g' {} + 2>/dev/null

# 3. 强制修改 .config 文件，确保彻底移除 aurora 并保留 argon
sed -i 's/CONFIG_PACKAGE_luci-theme-aurora=y/# CONFIG_PACKAGE_luci-theme-aurora is not set/g' .config
sed -i 's/CONFIG_PACKAGE_luci-app-aurora-config=y/# CONFIG_PACKAGE_luci-app-aurora-config is not set/g' .config
sed -i 's/# CONFIG_PACKAGE_luci-theme-argon is not set/CONFIG_PACKAGE_luci-theme-argon=y/g' .config
sed -i 's/# CONFIG_PACKAGE_luci-app-argon-config is not set/CONFIG_PACKAGE_luci-app-argon-config=y/g' .config

# 4. 解决 dnsmasq 冲突（日志里 Error 255 的元凶）
sed -i 's/CONFIG_PACKAGE_dnsmasq=y/# CONFIG_PACKAGE_dnsmasq is not set/g' .config
sed -i 's/# CONFIG_PACKAGE_dnsmasq-full is not set/CONFIG_PACKAGE_dnsmasq-full=y/g' .config

# 5. 解决循环依赖报错（防止 make defconfig 崩溃，必须提前关闭冲突包）
sed -i 's/CONFIG_PACKAGE_kmod-oaf=y/# CONFIG_PACKAGE_kmod-oaf is not set/g' .config
sed -i 's/CONFIG_PACKAGE_ndisc6=y/# CONFIG_PACKAGE_ndisc6 is not set/g' .config
sed -i 's/CONFIG_PACKAGE_rdisc6=y/# CONFIG_PACKAGE_rdisc6 is not set/g' .config
sed -i 's/CONFIG_PACKAGE_mihomo-alpha=y/# CONFIG_PACKAGE_mihomo-alpha is not set/g' .config
sed -i 's/CONFIG_PACKAGE_mihomo-meta=y/# CONFIG_PACKAGE_mihomo-meta is not set/g' .config

echo "✅ 全局依赖修复完成，只保留 Argon"

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

# ========== 精简 MTK 默认包 ==========
echo "=== 精简 MTK 默认包 ==="

# 1) 从 Makefile 删除 USB + btrfs
if [ -f "target/linux/mediatek/Makefile" ]; then
  sed -i 's/kmod-usb2 //g; s/kmod-usb3 //g; s/kmod-usb-net-rndis //g; s/usbutils//g; s/kmod-fs-btrfs //g' \
    target/linux/mediatek/Makefile
  echo "--- Makefile 修改后 ---"
  sed -n '14,23p' target/linux/mediatek/Makefile
else
  echo "⚠️ 未找到 target/linux/mediatek/Makefile"
fi

# 2) 从 target.mk 删除 safexcel（连带 eip197 自动消失）
if [ -f "target/linux/mediatek/filogic/target.mk" ]; then
  sed -i 's/kmod-crypto-hw-safexcel //g' \
    target/linux/mediatek/filogic/target.mk
  echo "--- target.mk 修改后 ---"
  cat target/linux/mediatek/filogic/target.mk
else
  echo "⚠️ 未找到 target/linux/mediatek/filogic/target.mk"
fi

# ========== 完美伪装 vermagic（改内核编译规则） ==========
echo "=== 完美伪装 vermagic ==="

WRT_ROOT="${GITHUB_WORKSPACE}/wrt"
cd "$WRT_ROOT" || cd /mnt/build_wrt || exit 1

# 1. 在源码根目录创建自定义 vermagic 文件
echo "a8b93917f464536104594f27d870028d" > "$WRT_ROOT/vermagic"
echo "--- 已创建 $WRT_ROOT/vermagic ---"
cat "$WRT_ROOT/vermagic"

# 2. 修改 kernel-defaults.mk
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
    # 匹配大写 MKHASH
    if echo "$line" | grep -q '\.config\.set.*MKHASH.*\.vermagic'; then
      printf '\tcp $(TOPDIR)/vermagic $(LINUX_DIR)/.vermagic\n' >> "$TMPFILE"
    fi
  done < "$KDM"
  mv "$TMPFILE" "$KDM"
  echo "✅ kernel-defaults.mk 已修改"
fi

# 3. 强制校验
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