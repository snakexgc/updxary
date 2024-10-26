#!/bin/bash

updateXray() {
    echo "=== 开始自动更新 Xray ==="

    # 获取 Xray-core 最新版本信息
    echo "获取 Xray-core 最新版本信息..."
    releases=$(curl -s "https://api.github.com/repos/XTLS/Xray-core/releases?per_page=5")
    if [[ -z "$releases" ]]; then
        echo "无法获取版本信息，请检查网络连接或 GitHub API 状态。"
        exit 1
    fi

    # 获取时间上最新的版本（不考虑是否为预览版）
    latest_version=$(echo "$releases" | jq -r '.[0].tag_name' | sed 's/^v//')  # 移除 'v' 前缀
    if [[ -z "$latest_version" ]]; then
        echo "未找到有效的版本号，请检查 GitHub API 返回的数据格式。"
        exit 1
    fi
    echo "云端最新 Xray-core 版本: ${latest_version}"

    # 检查本地 Xray-core 版本
    if [[ -f "/etc/v2ray-agent/xray/xray" ]]; then
        local_version=$(/etc/v2ray-agent/xray/xray -version | head -n 1 | awk '{print $2}' | sed 's/^v//')  # 移除 'v' 前缀
        echo "当前本地 Xray-core 版本: ${local_version}"

        if [[ "$local_version" == "$latest_version" ]]; then
            echo "Xray-core 已是最新版本，无需更新。"
            return
        fi
    else
        echo "本地未安装 Xray-core，进行初次安装..."
    fi

    # 确定 CPU 类型
    echo "检测系统 CPU 架构..."
    case "$(uname -m)" in
        x86_64|amd64)
            xrayCoreCPUVendor="xray-linux-64"
            ;;
        armv8|aarch64)
            xrayCoreCPUVendor="xray-linux-arm64-v8a"
            ;;
        *)
            echo "不支持的 CPU 架构：$(uname -m)"
            exit 1
            ;;
    esac
    echo "检测到的 CPU 架构：${xrayCoreCPUVendor}"

    # 下载新版本
    echo "下载 Xray-core 版本 ${latest_version}..."
    wget -c -q --show-progress -P /etc/v2ray-agent/xray/ "https://github.com/XTLS/Xray-core/releases/download/v${latest_version}/${xrayCoreCPUVendor}.zip"
    
    if [[ ! -f "/etc/v2ray-agent/xray/${xrayCoreCPUVendor}.zip" ]]; then
        echo "核心下载失败，请检查网络连接后重试。"
        exit 1
    else
        echo "下载成功：/etc/v2ray-agent/xray/${xrayCoreCPUVendor}.zip"
    fi

    # 解压并清理
    echo "解压 Xray-core 文件..."
    unzip -o "/etc/v2ray-agent/xray/${xrayCoreCPUVendor}.zip" -d /etc/v2ray-agent/xray >/dev/null
    if [[ $? -ne 0 ]]; then
        echo "解压失败，请检查文件完整性或系统权限。"
        exit 1
    fi
    rm -rf "/etc/v2ray-agent/xray/${xrayCoreCPUVendor}.zip"
    echo "解压完成并清理压缩文件。"

    # 设置执行权限
    chmod +x /etc/v2ray-agent/xray/xray
    echo "已赋予 Xray 执行权限。"

    # 更新 geoip 和 geosite
    updateGeoData

    # 检查更新是否成功
    installed_version=$(/etc/v2ray-agent/xray/xray -version | head -n 1 | awk '{print $2}' | sed 's/^v//')  # 移除 'v' 前缀
    if [[ "$installed_version" == "$latest_version" ]]; then
        echo "Xray 已成功更新到版本 ${installed_version}"
    else
        echo "Xray 更新失败，当前版本为 ${installed_version}，目标版本为 ${latest_version}"
        exit 1
    fi

    # 重启 Xray 服务
    echo "重启 Xray 服务..."
    systemctl restart xray
    if [[ $? -eq 0 ]]; then
        echo "Xray 服务已成功重启"
    else
        echo "Xray 服务重启失败，请检查服务状态。"
    fi
}

updateGeoData() {
    echo "=== 更新 geoip 和 geosite 数据 ==="

    # 获取最新的 geo 数据版本
    echo "获取 geo 数据版本信息..."
    version=$(curl -s https://api.github.com/repos/Loyalsoldier/v2ray-rules-dat/releases?per_page=1 | jq -r '.[0].tag_name')
    if [[ -z "$version" ]]; then
        echo "无法获取 geo 数据版本信息，请检查网络连接。"
        exit 1
    fi
    echo "Geo 数据版本: ${version}"

    # 清理旧的 geo 数据
    echo "清理旧的 geo 数据..."
    rm /etc/v2ray-agent/xray/geo* >/dev/null 2>&1

    # 下载新的 geo 数据
    echo "下载 geo 数据文件..."
    wget -c -q --show-progress -P /etc/v2ray-agent/xray/ "https://github.com/Loyalsoldier/v2ray-rules-dat/releases/download/${version}/geosite.dat"
    wget -c -q --show-progress -P /etc/v2ray-agent/xray/ "https://github.com/Loyalsoldier/v2ray-rules-dat/releases/download/${version}/geoip.dat"

    if [[ -f "/etc/v2ray-agent/xray/geosite.dat" && -f "/etc/v2ray-agent/xray/geoip.dat" ]]; then
        echo "Geo 数据更新成功"
    else
        echo "Geo 数据更新失败，请检查网络连接和文件路径。"
        exit 1
    fi
}

# 主执行
updateXray
