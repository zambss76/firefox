# 多阶段构建以减小最终镜像大小
# 阶段1: 构建noVNC
FROM alpine:latest as novnc-builder

# 安装必要的工具，包括openssl
RUN apk add --no-cache git openssl && \
    git clone --depth 1 https://github.com/novnc/noVNC.git /tmp/novnc && \
    git clone --depth 1 https://github.com/novnc/websockify /tmp/novnc/utils/websockify && \
    # 在构建阶段创建自签名证书
    mkdir -p /tmp/novnc/utils/ssl && \
    cd /tmp/novnc/utils/ssl && \
    openssl req -x509 -nodes -newkey rsa:2048 \
    -keyout self.pem -out self.pem -days 3650 \
    -subj "/C=US/ST=State/L=City/O=Organization/CN=localhost"

# 阶段2: 最终镜像
FROM alpine:latest

LABEL org.opencontainers.image.title="Lightweight Firefox with noVNC"
LABEL org.opencontainers.image.description="Ultra-lightweight Firefox browser with noVNC web access and VNC password support"
LABEL org.opencontainers.image.vendor="Your Name"
LABEL org.opencontainers.image.licenses="MIT"

# 安装最小化软件包 - 添加openssl用于证书生成（如果需要的话）
RUN apk add --no-cache \
    firefox \
    xvfb \
    x11vnc \
    supervisor \
    bash \
    fluxbox \
    openssl \
    && rm -rf /var/cache/apk/*

# 创建必要的目录
RUN mkdir -p /var/log/supervisor /etc/supervisor/conf.d /root/.vnc

# 从构建阶段复制noVNC（包括SSL证书）
COPY --from=novnc-builder /tmp/novnc /opt/novnc

# 复制配置文件
COPY supervisord.conf /etc/supervisor/supervisord.conf
COPY start.sh /usr/local/bin/start.sh

# 设置权限
RUN chmod +x /usr/local/bin/start.sh

# 设置默认noVNC首页
RUN echo '<html><head><meta http-equiv="refresh" content="0;url=vnc.html"></head><body></body></html>' > /opt/novnc/index.html

# 暴露端口
EXPOSE 7860 5900

# 设置环境变量
ENV DISPLAY=:99
ENV DISPLAY_WIDTH=1280
ENV DISPLAY_HEIGHT=720
ENV VNC_PASSWORD=changeme
ENV VNC_PORT=5900
ENV NOVNC_PORT=7860

# 健康检查
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
    CMD netstat -an | grep :${NOVNC_PORT} > /dev/null 2>&1 || exit 1

# 启动服务
CMD ["/usr/local/bin/start.sh"]
