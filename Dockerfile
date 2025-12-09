# 阶段1: 构建器 - 仅准备静态资产
FROM alpine:latest AS builder
RUN apk add --no-cache git openssl
RUN git clone --depth 1 --branch v1.4.0 https://github.com/novnc/noVNC.git /assets/novnc && \
    git clone --depth 1 --branch v0.11.0 https://github.com/novnc/websockify /assets/novnc/utils/websockify
RUN mkdir -p /assets/novnc/utils/ssl && \
    cd /assets/novnc/utils/ssl && \
    openssl req -x509 -nodes -newkey rsa:2048 \
        -keyout self.pem -out self.pem -days 3650 \
        -subj "/C=US/ST=State/L=City/O=Organization/CN=localhost" 2>/dev/null
RUN rm -rf /assets/novnc/.git /assets/novnc/utils/websockify/.git

# 阶段2: 最终运行时镜像 - 使用 edge 分支以确保包可用性
FROM alpine:edge  # 关键修改：从 latest 改为 edge

LABEL org.opencontainers.image.title="Lightweight Firefox with noVNC (中文支持)"

# 安装运行时依赖及中文支持
RUN --mount=type=cache,target=/var/cache/apk \
    # 更新仓库索引，并添加 community 仓库（许多桌面包在此）
    apk update && apk add --no-cache \
    # 核心应用（在 edge/community 仓库中可用）
    firefox-esr \
    x11vnc \
    xvfb \
    supervisor \
    fluxbox \
    # 基础工具和字体
    bash \
    curl \
    tzdata \
    locales \
    font-misc-misc \
    font-cursor-misc \
    ttf-dejavu \
    # 中文字体（改用更通用的包名）
    font-noto \
    font-noto-cjk \
    font-noto-emoji \
    && \
    # 清理并创建目录
    rm -rf /var/cache/apk/* && \
    mkdir -p /var/log/supervisor /etc/supervisor/conf.d /root/.vnc /root/.mozilla

# 暴露端口和环境变量
EXPOSE 5800 5900
ENV DISPLAY=:99 \
    DISPLAY_WIDTH=1280 \
    DISPLAY_HEIGHT=720 \
    VNC_PASSWORD=changeme \
    VNC_PORT=5900 \
    NOVNC_PORT=5800 \
    LANG=zh_CN.UTF-8 \
    LANGUAGE=zh_CN:zh:en_US:en \
    LC_ALL=zh_CN.UTF-8 \
    TZ=Asia/Shanghai \
    XVFB_WHD="${DISPLAY_WIDTH}x${DISPLAY_HEIGHT}x24"

WORKDIR /opt/novnc
USER firefox
CMD ["/usr/local/bin/start.sh"]
