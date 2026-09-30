#!/bin/bash

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

# 2. 修改 kernel-defaults.mk，在内核生成 .vermagic 之后覆盖它
KDM="$WRT_ROOT/include/kernel-defaults.mk"
if [ ! -f "$KDM" ]; then
  echo "❌ 未找到 $KDM"
else
  # 避免重复添加
  if grep -q "cp \$(TOPDIR)/vermagic \$(LINUX_DIR)/.vermagic" "$KDM"; then
    echo "⚠️ 已经存在 cp 行，跳过"
  else
    # 用 awk 精确匹配第 130 行，在它后面插入 cp 行
    awk '
      /grep .*\.config\.set.*mkhash md5.*\.vermagic/ {
        print
        print "\tcp $(TOPDIR)/vermagic $(LINUX_DIR)/.vermagic"
        next
      }
      { print }
    ' "$KDM" > "$KDM.tmp" && mv "$KDM.tmp" "$KDM"
    echo "✅ kernel-defaults.mk 已修改"
  fi
  echo "--- 修改后 125-135 行 ---"
  sed -n '125,135p' "$KDM"
fi

echo "=== vermagic 完美伪装完成 ==="

echo "=== MTK 默认包精简完成 ==="
echo "✅ diy.sh 执行完成"
