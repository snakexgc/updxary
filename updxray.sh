#!/bin/bash

updateXray() {
    echo "开始自动更新 Xray..."

    # 获取最新的5个版本
    releases=$(curl -s "https://api.github.com/repos/XTLS/Xray-core/releases?per_page=5")

    # 尝试获取最新的非预览版本
    stable_version=$(echo "$releases" | jq -r '.[] | select(.prerelease==false) | .tag_name' | head -1)

    # 如果没有找到稳定版本，就选择最新的预览版本
    if [ -z "$stable_version" ]; then
        version=$(echo "$releases" | jq -r '.[0].tag_name')
        echo "未找到稳定版本，选择最新的预览版本: ${version}"
    else
        version=$stable_version
        echo "找到最新的稳定版本: ${version}"
    fi

    echo "选定的 Xray-core 版本: ${version}"

    # 确定 CPU 类型
    case "$(uname -m)" in
        x86_64|amd64)
            xrayCoreCPUVendor="xray-linux-64"
            ;;
        armv8|aarch64)
            xrayCoreCPUVendor="xray-linux-arm64-v8a"
            ;;
        *)
            echo "不支持的 CPU 架构"
            exit 1
            ;;
    esac

    # 下载新版本
    wget -c -q --show-progress -P /etc/v2ray-agent/xray/ "https://github.com/XTLS/Xray-core/releases/download/${version}/${xrayCoreCPUVendor}.zip"

    if [[ ! -f "/etc/v2ray-agent/xray/${xrayCoreCPUVendor}.zip" ]]; then
        echo "核心下载失败，请检查网络连接后重试。"
        exit 1
    fi

    # 解压并清理
    unzip -o "/etc/v2ray-agent/xray/${xrayCoreCPUVendor}.zip" -d /etc/v2ray-agent/xray >/dev/null
    rm -rf "/etc/v2ray-agent/xray/${xrayCoreCPUVendor}.zip"

    # 更新 geoip 和 geosite
    updateGeoData

    chmod 655 /etc/v2ray-agent/xray/xray

    echo "Xray 已成功更新到版本 ${version}"

    # 重启 Xray 服务
    systemctl restart xray
    echo "Xray 服务已重启"
}

updateGeoData() {
    echo "更新 geoip 和 geosite 数据..."

    version=$(curl -s https://api.github.com/repos/Loyalsoldier/v2ray-rules-dat/releases?per_page=1 | jq -r '.[0].tag_name')
    echo "Geo 数据版本: ${version}"

    rm /etc/v2ray-agent/xray/geo* >/dev/null 2>&1

    wget -c -q --show-progress -P /etc/v2ray-agent/xray/ "https://github.com/Loyalsoldier/v2ray-rules-dat/releases/download/${version}/geosite.dat"
    wget -c -q --show-progress -P /etc/v2ray-agent/xray/ "https://github.com/Loyalsoldier/v2ray-rules-dat/releases/download/${version}/geoip.dat"

    echo "Geo 数据更新成功"
}

# 主执行
updateXray