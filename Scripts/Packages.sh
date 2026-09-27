#!/bin/bash
# SPDX-License-Identifier: MIT
# Copyright (C) 2026 VIKINGYFY

#安装和更新软件包
UPDATE_PACKAGE() {
	local PKG_NAME=$1
	local PKG_REPO=$2
	local PKG_BRANCH=$3
	local PKG_SPECIAL=$4
	local PKG_LIST=("$PKG_NAME" $5)  # 第5个参数为自定义名称列表
	local REPO_NAME=${PKG_REPO#*/}
	local REPO_PATH="./$REPO_NAME"

	echo " "

	# 删除本地可能存在的不同名称的软件包
	for NAME in "${PKG_LIST[@]}"; do
		# 查找匹配的目录
		echo "Search directory: $NAME"
		local FOUND_DIRS=$(find ./feeds/luci/ ./feeds/packages/ -maxdepth 3 -type d -iname "*$NAME*" 2>/dev/null)

		# 删除找到的目录
		if [ -n "$FOUND_DIRS" ]; then
			while read -r DIR; do
				rm -rf "$DIR"
				echo "Delete directory: $DIR"
			done <<< "$FOUND_DIRS"
		else
			echo "Not fonud directory: $NAME"
		fi
	done

	# 克隆 GitHub 仓库
	git clone --depth=1 --single-branch --branch $PKG_BRANCH "https://github.com/$PKG_REPO.git" $REPO_PATH

	# 处理克隆的仓库
	if [[ "$PKG_SPECIAL" == "pkg" ]]; then
		find $REPO_PATH/*/ -maxdepth 3 -type d -iname "*$PKG_NAME*" -prune -exec cp -rf {} ./package \;
		rm -rf $REPO_PATH
	fi
}

# 调用示例
# UPDATE_PACKAGE "OpenAppFilter" "destan19/OpenAppFilter" "master" "" "custom_name1 custom_name2"
# UPDATE_PACKAGE "open-app-filter" "destan19/OpenAppFilter" "master" "" "luci-app-appfilter oaf" 这样会把原有的open-app-filter，luci-app-appfilter，oaf相关组件删除，不会出现coremark错误。

# UPDATE_PACKAGE "包名" "项目地址" "项目分支" "pkg，可选，从大杂烩中单独提取包名插件"
UPDATE_PACKAGE "argon" "sbwml/luci-theme-argon" "openwrt-25.12"
UPDATE_PACKAGE "aurora" "eamonxg/luci-theme-aurora" "master"
UPDATE_PACKAGE "aurora-config" "eamonxg/luci-app-aurora-config" "master"
UPDATE_PACKAGE "kucat" "sirpdboy/luci-theme-kucat" "master"
UPDATE_PACKAGE "kucat-config" "sirpdboy/luci-app-kucat-config" "master"
UPDATE_PACKAGE "noobwrt" "nooblk-98/luci-theme-noobwrt" "master"
UPDATE_PACKAGE "shadcn" "eamonxg/luci-theme-shadcn" "main"
UPDATE_PACKAGE "theme-fluent" "LazuliKao/luci-theme-fluent" "main"

UPDATE_PACKAGE "momo" "nikkinikki-org/OpenWrt-momo" "main"
UPDATE_PACKAGE "nikki" "nikkinikki-org/OpenWrt-nikki" "main"
UPDATE_PACKAGE "openclash" "vernesong/OpenClash" "dev" "pkg"
UPDATE_PACKAGE "passwall" "Openwrt-Passwall/openwrt-passwall" "main" "pkg"
UPDATE_PACKAGE "passwall2" "Openwrt-Passwall/openwrt-passwall2" "main" "pkg"

UPDATE_PACKAGE "diskmanager" "4IceG/luci-app-mini-diskmanager" "main"
UPDATE_PACKAGE "easytier" "EasyTier/luci-app-easytier" "main"
UPDATE_PACKAGE "qmodem" "FUjr/QModem" "main"
UPDATE_PACKAGE "vnt" "lmq8267/luci-app-vnt" "main"

UPDATE_PACKAGE "diskman" "sbwml/luci-app-diskman" "main"
UPDATE_PACKAGE "mosdns" "sbwml/luci-app-mosdns" "v5" "" "v2dat"
UPDATE_PACKAGE "openlist2" "sbwml/luci-app-openlist2" "main"
UPDATE_PACKAGE "qbittorrent" "sbwml/luci-app-qbittorrent" "master" "" "qt6base qt6tools rblibtorrent"
UPDATE_PACKAGE "quickfile" "sbwml/luci-app-quickfile" "main"

UPDATE_PACKAGE "ddns-go" "sirpdboy/luci-app-ddns-go" "main"
UPDATE_PACKAGE "netspeedtest" "sirpdboy/netspeedtest" "main" "" "homebox ookla-speedtest"
UPDATE_PACKAGE "netwizard" "sirpdboy/luci-app-netwizard" "main"
UPDATE_PACKAGE "partexp" "sirpdboy/luci-app-partexp" "main"
UPDATE_PACKAGE "timecontrol" "sirpdboy/luci-app-timecontrol" "main"

UPDATE_PACKAGE "natmapt" "muink/openwrt-natmapt" "master"
UPDATE_PACKAGE "stuntman" "muink/openwrt-stuntman" "master"
UPDATE_PACKAGE "luci-app-natmapt" "muink/luci-app-natmapt" "master"

UPDATE_PACKAGE "airpi3000m" "LianXia233/luci-app-airpi3000m-fancontrol" "main"
UPDATE_PACKAGE "h5000m" "LianXia233/luci-app-h5000m-netmode" "main"
UPDATE_PACKAGE "qmodem-generic" "LianXia233/luci-app-qmodem-generic" "main"

#更新软件包版本
UPDATE_VERSION() {
	local PKG_NAME=$1
	local PKG_MARK=${2:-false}
	local PKG_FILES=$(find ./ ./feeds/packages/ -maxdepth 3 -type f -wholename "*/$PKG_NAME/Makefile")

	if [ -z "$PKG_FILES" ]; then
		echo "$PKG_NAME not found!"
		return
	fi

	echo -e "\n$PKG_NAME version update has started!"

	for PKG_FILE in $PKG_FILES; do
		local PKG_REPO=$(grep -Po "PKG_SOURCE_URL:=https://.*github.com/\K[^/]+/[^/]+(?=.*)" $PKG_FILE)
		local PKG_TAG=$(curl -sL "https://api.github.com/repos/$PKG_REPO/releases" | jq -r "map(select(.prerelease == $PKG_MARK)) | first | .tag_name")

		local OLD_VER=$(grep -Po "PKG_VERSION:=\K.*" "$PKG_FILE")
		local OLD_URL=$(grep -Po "PKG_SOURCE_URL:=\K.*" "$PKG_FILE")
		local OLD_FILE=$(grep -Po "PKG_SOURCE:=\K.*" "$PKG_FILE")
		local OLD_HASH=$(grep -Po "PKG_HASH:=\K.*" "$PKG_FILE")

		local PKG_URL=$([[ "$OLD_URL" == *"releases"* ]] && echo "${OLD_URL%/}/$OLD_FILE" || echo "${OLD_URL%/}")

		local NEW_VER=$(echo $PKG_TAG | sed -E 's/[^0-9]+/\./g; s/^\.|\.$//g')
		local NEW_URL=$(echo $PKG_URL | sed "s/\$(PKG_VERSION)/$NEW_VER/g; s/\$(PKG_NAME)/$PKG_NAME/g")
		local NEW_HASH=$(curl -sL "$NEW_URL" | sha256sum | cut -d ' ' -f 1)

		echo "old version: $OLD_VER $OLD_HASH"
		echo "new version: $NEW_VER $NEW_HASH"

		if [[ "$NEW_VER" =~ ^[0-9].* ]] && dpkg --compare-versions "$OLD_VER" lt "$NEW_VER"; then
			sed -i "s/PKG_VERSION:=.*/PKG_VERSION:=$NEW_VER/g" "$PKG_FILE"
			sed -i "s/PKG_HASH:=.*/PKG_HASH:=$NEW_HASH/g" "$PKG_FILE"
			echo "$PKG_FILE version has been updated!"
		else
			echo "$PKG_FILE version is already the latest!"
		fi
	done
}

#UPDATE_VERSION "软件包名" "测试版，true，可选，默认为否"
#UPDATE_VERSION "sing-box"

#引入私有扩展脚本
if [ -f "$GITHUB_WORKSPACE/Scripts/PRIVATE.sh" ]; then
	source "$GITHUB_WORKSPACE/Scripts/PRIVATE.sh"
fi

# ========== 拉取第三方包 ==========
echo "===== 开始拉取第三方包 ====="
# 注意：WRT-CORE 已经把当前目录切换到 package/，这里不要再 cd

# UA3F
echo "===== 拉取 UA3F ====="
git clone --depth 1 https://github.com/SunBK201/UA3F.git UA3F 2>/dev/null || true

# OpenAppFilter (OAF)
echo "===== 拉取 OpenAppFilter ====="
rm -rf open-app-filter oaf luci-app-oaf appfilter 2>/dev/null || true
git clone --depth 1 https://github.com/destan19/OpenAppFilter.git OpenAppFilter 2>/dev/null || true

# rkp-ipid
echo "===== 拉取 rkp-ipid ====="
git clone --depth 1 https://github.com/CHN-beta/rkp-ipid.git rkp-ipid 2>/dev/null || true

# quickstart 全家桶
echo "===== 拉取 quickstart 全家桶 ====="
git clone --depth 1 --filter=blob:none --sparse https://github.com/kenzok8/small-package.git temp_kenzok8
cd temp_kenzok8
git sparse-checkout set quickstart luci-app-quickstart luci-app-store luci-lib-taskd luci-lib-xterm taskd
cd ..
mv temp_kenzok8/quickstart ./ 2>/dev/null || true
mv temp_kenzok8/luci-app-quickstart ./ 2>/dev/null || true
mv temp_kenzok8/luci-app-store ./ 2>/dev/null || true
mv temp_kenzok8/luci-lib-taskd ./ 2>/dev/null || true
mv temp_kenzok8/luci-lib-xterm ./ 2>/dev/null || true
mv temp_kenzok8/taskd ./ 2>/dev/null || true
rm -rf temp_kenzok8

# ========== 清理 quickstart 多余依赖 ==========
echo "===== 清理 quickstart 依赖 ====="
for file in $(find . -path "*quickstart*" -name "Makefile" 2>/dev/null); do
  cp "$file" "$file.bak"
  sed -i -E 's/\+shadow[a-z0-9-]*\b//g' "$file"
  sed -i -E 's/\+smartmontools[a-z0-9-]*\b//g' "$file"
  sed -i -E 's/\+smartd\b//g' "$file"
  sed -i -E 's/\+mdadm\b//g' "$file"
done
echo "✅ quickstart 依赖清理完成"

echo "===== 第三方包拉取完成 ====="

# ========== 拉取 minieap 校园网认证 ==========
echo "===== 拉取 minieap 与 LuCI 界面 ====="

# minieap 后端（BoringCat 打包了 updateing/minieap 的源码 + OpenWrt Makefile）
rm -rf minieap luci-app-minieap 2>/dev/null || true
git clone --depth 1 https://github.com/BoringCat/minieap-openwrt.git minieap 2>/dev/null || true

# LuCI 界面
git clone --depth 1 https://github.com/BoringCat/luci-app-minieap.git luci-app-minieap 2>/dev/null || true

# 兜底：如果 minieap-openwrt 拉取失败，用 updateing 原版 + 手动 Makefile
if [ ! -d "minieap" ] || [ ! -f "minieap/Makefile" ]; then
  echo "⚠️ BoringCat/minieap-openwrt 拉取失败，尝试使用 updateing 原版"
  rm -rf minieap
  git clone --depth 1 https://github.com/updateing/minieap.git minieap 2>/dev/null || true
  # 注意：原版无 Makefile，需要自行补充，否则编译会跳过
fi

echo "===== minieap 拉取完成 ====="
