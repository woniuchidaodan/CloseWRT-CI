#!/bin/bash

# ========== 根据 DEVICE 确定主机名 ==========
if [ "$DEVICE" = "AX3000T" ]; then
    HOSTNAME="AX3000T"
elif [ "$DEVICE" = "WR30U" ]; then
    HOSTNAME="WR30U"
else
    HOSTNAME="ImmortalWrt"
fi
echo "📦 当前设备: $DEVICE，主机名: $HOSTNAME"

# ========== 修改 IP ==========
sed -i 's/192.168.1.1/192.168.1.2/g' package/base-files/files/bin/config_generate

# ========== 修改主机名 ==========
sed -i "s/ImmortalWrt/$HOSTNAME/g" package/base-files/files/bin/config_generate

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

# ========== 默认 WiFi ==========
mkdir -p package/base-files/files/etc/config
cat > package/base-files/files/etc/config/wireless << 'EOF'
config wifi-device 'radio0'
    option type 'mac80211'
    option path 'platform/soc/18000000.wifi'
    option channel '1'
    option band '2g'
    option htmode 'HE20'
    option disabled '0'

config wifi-iface 'default_radio0'
    option device 'radio0'
    option network 'lan'
    option mode 'ap'
    option ssid 'CMCC-7920'
    option encryption 'psk2'
    option key '123456789'

config wifi-device 'radio1'
    option type 'mac80211'
    option path 'platform/soc/18000000.wifi+1'
    option channel '36'
    option band '5g'
    option htmode 'HE80'
    option disabled '0'

config wifi-iface 'default_radio1'
    option device 'radio1'
    option network 'lan'
    option mode 'ap'
    option ssid 'CMCC-7920'
    option encryption 'psk2'
    option key '123456789'
EOF
