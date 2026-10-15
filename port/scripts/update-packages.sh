#!/bin/bash
# 安装和更新第三方软件包
# 此脚本在 openwrt/package/ 目录下运行，在 feeds install 之后执行

set -e

UPDATE_PACKAGE() {
	local -n PKG_NAMES=$1
	local PKG_REPO=$2
	local PKG_BRANCH=$3
	local PKG_SPECIAL=$4
	local REPO_NAME=${PKG_REPO#*/}

	echo " "
	echo "=========================================="
	(IFS=" | "; echo "Processing: ${PKG_NAMES[*]} from $PKG_REPO, repository: $REPO_NAME, branch: $PKG_BRANCH" )
	echo "=========================================="

	# 删除 feeds 中可能存在的同名软件包
	for NAME in "${PKG_NAMES[@]}"; do
	    if [ -z "$NAME" ]; then
		    continue
		fi
		
		echo "Search directory: $NAME"
		local FOUND_DIRS=$(find ../feeds/luci/ ../feeds/packages/ -maxdepth 3 -type d -iname "*$NAME*" 2>/dev/null)

		if [ -n "$FOUND_DIRS" ]; then
		    while read -r DIR; do
				rm -rf "$DIR"
				echo "Delete directory: $DIR"
			done <<< "$FOUND_DIRS"
		else
			echo "Not found directory: $NAME"
		fi
	done

	# 克隆 GitHub 仓库
	git clone --depth=1 --single-branch --branch "$PKG_BRANCH" "https://github.com/$PKG_REPO.git"

	if [ ! -d "$REPO_NAME" ]; then
	    ls
		echo "ERROR: Failed to clone $PKG_REPO"
		return 1
	fi

	# 处理克隆的仓库
	if [[ "$PKG_SPECIAL" == "pkg" ]]; then
	   for NAME in "${PKG_NAMES[@]}"; do
		    if [[ "$REPO_NAME" == "$NAME" ]]; then
			   echo "Rename repository folder to ${REPO_NAME}1 as it is same as target pkg folder"
			   mv ./$REPO_NAME ./${REPO_NAME}1
			   REPO_NAME=${REPO_NAME}1
			   break
			fi
		done
		# 从大杂烩仓库中提取特定包
		for NAME in "${PKG_NAMES[@]}"; do
	        if [ -z "$NAME" ]; then
		        continue
		    fi
		    find ./$REPO_NAME/*/ -maxdepth 3 -type d -iname "*$NAME*" -prune -exec cp -rf {} ./ \;
		done
		rm -rf ./$REPO_NAME/
	# elif [[ "$PKG_SPECIAL" == "name" ]]; then
		# 重命名仓库
	#	mv -f $REPO_NAME $PKG_NAME
	fi
	
    (IFS=" | "; echo "Done: ${PKG_NAMES[*]}")
}

echo "Starting package updates..."

# client time control
pkgs=("luci-app-timecontrol"); UPDATE_PACKAGE pkgs "EricYin/luci-app-timecontrol" "custom"; unset pkgs
sed -i 's|include ../../luci.mk|include $(TOPDIR)/feeds/luci/luci.mk|' ./luci-app-timecontrol/Makefile

echo "=========================================="
echo "Package updates completed, list packages folder: "
ls
