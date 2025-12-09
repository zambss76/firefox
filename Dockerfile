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

# 阶段2: 最终运行时镜像 ---> 关键修复行（原第14行左右）
FROM alpine:edge
LABEL org.opencontainers.image.title="Lightweight Firefox with noVNC (中文支持)"

# 安装运行时依赖及中文支持
RUN --mount=type=cache,target=/var/cache/apk \
    apk update && apk add --no-cache \
    firefox-esr \
    x11vnc \
    xvfb \
    supervisor \
    fluxbox \
    bash \
    curl \
    tzdata \
    locales \
    font-misc-misc \
    font-cursor-misc \
    ttf-dejavu \
    font-noto \
    font-noto-cjk \
    font-noto-emoji \
    && \
    rm -rf /var/cache/apk/* && \
    mkdir -p /var/log/supervisor /etc/supervisor/conf.d /root/.vnc /root/.mozilla

# 配置中文环境
RUN echo "zh_CN.UTF-8 UTF-8" >> /etc/locale.gen && locale-gen && \
    echo 'LANG="zh_CN.UTF-8"' > /etc/locale.conf && \
    echo 'LC_ALL="zh_CN.UTF-8"' >> /etc/locale.conf

# 复制配置文件
COPY supervisord.conf /etc/supervisor/supervisord.conf
COPY start.sh /usr/local/bin/start.sh
COPY fluxbox-init /etc/fluxbox-init
COPY --from=builder /assets/novnc /opt/novnc

# 设置noVNC默认页面
RUN echo '<!DOCTYPE html><html lang="zh-CN"><head><meta charset="UTF-8"><meta http-equiv="refresh" content="0;url=vnc.html?autoconnect=true&resize=remote"></head><body><p>正在重定向到 noVNC 客户端...</p></body></html>' > /opt/novnc/index.html

# 设置权限
RUN chmod +x /usr/local/bin/start.sh && \
    adduser -D -u 1000 -g 1000 -s /bin/bash firefox && \
    chown -R firefox:firefox /opt/novnc /home/firefox

# 暴露端口和环境变量
EXPOSE 7860 5900
ENV DISPLAY=:99 \
    DISPLAY_WIDTH=1280 \
    DISPLAY_HEIGHT=720 \
    VNC_PASSWORD=admin \
    VNC_PORT=5900 \
    NOVNC_PORT=7860 \
    LANG=zh_CN.UTF-8 \
    LANGUAGE=zh_CN:zh:en_US:en \
    LC_ALL=zh_CN.UTF-8 \
    TZ=Asia/Shanghai \
    XVFB_WHD="${DISPLAY_WIDTH}x${DISPLAY_HEIGHT}x24"

WORKDIR /opt/novnc
USER firefox
CMD ["/usr/local/bin/start.sh"]
