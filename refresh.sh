#!/bin/bash
PREFERRED_STORAGE="/home/firefox"
FALLBACK_STORAGE="/home/firefoxuser/.mozilla"
PREFS_FILE="/home/firefoxuser/firefox-prefs.js"

if [ -d "$PREFERRED_STORAGE" ] && [ -w "$PREFERRED_STORAGE" ]; then
    echo "使用持久化存储: $PREFERRED_STORAGE"
    DATA_DIR="$PREFERRED_STORAGE"
    mkdir -p "$DATA_DIR/firefox/default-release"
    [ -f "$PREFS_FILE" ] && cp -n "$PREFS_FILE" "$DATA_DIR/firefox/default-release/user.js"
else
    echo "使用内部存储: $FALLBACK_STORAGE"
    DATA_DIR="$FALLBACK_STORAGE"
    mkdir -p "$DATA_DIR/firefox/default-release"
    [ -f "$PREFS_FILE" ] && cp -n "$PREFS_FILE" "$DATA_DIR/firefox/default-release/user.js"
fi

export HOME="$DATA_DIR/.."
echo "启动 Firefox..."
exec firefox-esr --display=:99
