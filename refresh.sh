#!/bin/bash
echo "=== Firefox 容器启动 ==="

# 定义关键路径
PREFERRED_STORAGE="/home/firefox"    # 你希望优先使用的持久化存储路径
FALLBACK_STORAGE="/home/firefoxuser/.mozilla"  # 备用内部存储路径
PREFS_FILE="/home/firefoxuser/firefox-prefs.js" # 预置配置文件

# 智能配置和数据目录设置
if [ -d "$PREFERRED_STORAGE" ] && [ -w "$PREFERRED_STORAGE" ]; then
    echo "检测到可用的持久化存储: $PREFERRED_STORAGE"
    DATA_DIR="$PREFERRED_STORAGE"
    # 确保配置目录存在
    mkdir -p "$DATA_DIR/firefox/default-release"
    # 将预置配置复制到持久化存储（仅首次或配置更新时）
    if [ -f "$PREFS_FILE" ]; then
        cp -n "$PREFS_FILE" "$DATA_DIR/firefox/default-release/user.js"
    fi
else
    echo "未找到持久化存储，使用容器内部存储: $FALLBACK_STORAGE"
    DATA_DIR="$FALLBACK_STORAGE"
    mkdir -p "$DATA_DIR/firefox/default-release"
    # 使用内部配置
    if [ -f "$PREFS_FILE" ]; then
        cp -n "$PREFS_FILE" "$DATA_DIR/firefox/default-release/user.js"
    fi
fi

echo "Firefox 数据目录设置为: $DATA_DIR"

# 设置 Firefox 环境变量，指向选定的数据目录
export HOME="$DATA_DIR/.."  # Firefox 会寻找上级目录的 .mozilla 文件夹

# 启动 Firefox
echo "启动 Firefox (显示在 :99)..."
exec firefox-esr --display=:99
