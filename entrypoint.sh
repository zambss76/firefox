#!/bin/bash
set -e

echo "===== Firefox + noVNC 容器启动中 ====="

# 设置默认环境变量（如果在Docker运行时未指定）
: ${VNC_PASSWORD:=alpine}       # 默认密码为"alpine"
: ${NOVNC_PORT:=7860}           # 默认noVNC端口
: ${VNC_PORT:=5901}             # 默认VNC端口
: ${DISPLAY_WIDTH:=1280}        # 默认宽度
: ${DISPLAY_HEIGHT:=720}        # 默认高度
: ${DISPLAY_DEPTH:=24}          # 默认颜色深度

echo "环境变量配置:"
echo "  VNC_PASSWORD: ${VNC_PASSWORD}"
echo "  NOVNC_PORT: ${NOVNC_PORT}"
echo "  VNC_PORT: ${VNC_PORT}"
echo "  分辨率: ${DISPLAY_WIDTH}x${DISPLAY_HEIGHT}x${DISPLAY_DEPTH}"

# 创建必要的目录
mkdir -p ~/.vnc ~/.fluxbox /var/log

# 检查Firefox是否可用
if ! command -v firefox > /dev/null 2>&1; then
    echo "警告：未找到firefox命令，尝试安装..."
    apk add --no-cache firefox 2>/dev/null || true
fi

# VNC密码设置 - 使用可靠的非交互方法
if [ -n "$VNC_PASSWORD" ] && [ "$VNC_PASSWORD" != "none" ]; then
    echo "正在设置VNC密码..."
    
    # 方法1：使用x11vnc的非交互模式
    # 创建一个临时文件包含密码，然后使用here-document模拟交互
    echo "$VNC_PASSWORD" > /tmp/password.txt
    
    # 尝试非交互创建密码文件
    echo -e "$VNC_PASSWORD\n$VNC_PASSWORD\n" | x11vnc -storepasswd - ~/.vnc/passwd 2>&1 | grep -v "stty" || true
    
    # 检查是否创建成功
    if [ -f ~/.vnc/passwd ] && [ -s ~/.vnc/passwd ]; then
        chmod 600 ~/.vnc/passwd
        VNC_AUTH_OPT="-passwdfile ~/.vnc/passwd"
        echo "✓ VNC密码设置成功"
    else
        # 方法2：使用简单的方法设置密码
        echo "使用替代方法设置密码..."
        x11vnc -storepasswd "$VNC_PASSWORD" ~/.vnc/passwd 2>&1 | grep -v "stty" | grep -v "Enter" | grep -v "Verify" || true
        
        if [ -f ~/.vnc/passwd ]; then
            VNC_AUTH_OPT="-passwdfile ~/.vnc/passwd"
            echo "✓ VNC密码设置成功（替代方法）"
        else
            echo "⚠ VNC密码文件创建失败，使用无密码连接"
            VNC_AUTH_OPT="-nopw"
        fi
    fi
else
    echo "使用无密码VNC连接"
    VNC_AUTH_OPT="-nopw"
fi

# 生成Supervisor配置文件
cat > /etc/supervisord.conf << EOF
[supervisord]
nodaemon=true
logfile=/var/log/supervisord.log
loglevel=info

[program:xvfb]
command=Xvfb :0 -screen 0 ${DISPLAY_WIDTH}x${DISPLAY_HEIGHT}x${DISPLAY_DEPTH} -ac +extension GLX +render -noreset
autorestart=true
stdout_logfile=/var/log/xvfb.log
stderr_logfile=/var/log/xvfb.err.log

[program:fluxbox]
command=fluxbox
autorestart=true
environment=DISPLAY=:0
stdout_logfile=/var/log/fluxbox.log
stderr_logfile=/var/log/fluxbox.err.log

[program:x11vnc]
command=x11vnc -display :0 -forever -shared -rfbport ${VNC_PORT} ${VNC_AUTH_OPT} -noxdamage
autorestart=true
stdout_logfile=/var/log/x11vnc.log
stderr_logfile=/var/log/x11vnc.err.log

[program:novnc]
command=websockify --web /usr/share/novnc ${NOVNC_PORT} localhost:${VNC_PORT}
autorestart=true
stdout_logfile=/var/log/novnc.log
stderr_logfile=/var/log/novnc.err.log
EOF

# 创建Fluxbox配置
cat > ~/.fluxbox/init << EOF
session.screen0.toolbar.visible: false
session.screen0.fullMaximization: false
background: none
[begin] (fluxbox)
[exec] (Firefox) {firefox --display=:0 --no-remote --new-instance}
[end]
EOF

# 设置noVNC首页
if [ -f /usr/share/novnc/vnc.html ]; then
    cp /usr/share/novnc/vnc.html /usr/share/novnc/index.html
elif [ -f /usr/share/webapps/novnc/vnc.html ]; then
    cp /usr/share/webapps/novnc/vnc.html /usr/share/novnc/index.html
fi

echo "================================"
echo "容器启动完成!"
echo "访问地址: http://<主机IP>:${NOVNC_PORT}"
echo "VNC服务器端口: ${VNC_PORT}"
echo "显示分辨率: ${DISPLAY_WIDTH}x${DISPLAY_HEIGHT}"
if [ "$VNC_AUTH_OPT" != "-nopw" ]; then
    echo "VNC密码: 已启用 (${VNC_PASSWORD})"
else
    echo "VNC密码: 未设置"
fi
echo "================================"

# 启动所有服务
exec /usr/bin/supervisord -c /etc/supervisord.conf
