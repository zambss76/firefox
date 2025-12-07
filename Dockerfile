# 第一阶段：构建Firefox
FROM alpine:edge AS firefox-builder
WORKDIR /tmp

# 安装Firefox及依赖
RUN apk update && \
    apk add --no-cache \
    firefox \
    ttf-freefont \
    dbus

# 第二阶段：构建最终镜像
FROM alpine:edge
WORKDIR /root

# 安装依赖（包含sudo用于密码设置）
RUN apk update && \
    apk add --no-cache \
    bash \
    fluxbox \
    xvfb \
    x11vnc \
    supervisor \
    novnc \
    websockify \
    ttf-freefont \
    sudo \
    font-noto-cjk

# 从第一阶段复制Firefox
COPY --from=firefox-builder /usr/lib/firefox /usr/lib/firefox
COPY --from=firefox-builder /usr/bin/firefox /usr/bin/firefox
RUN ln -s /usr/lib/firefox/firefox /usr/local/bin/firefox

# 复制配置文件和启动脚本
COPY supervisord.conf /etc/supervisord.conf
COPY entrypoint.sh /entrypoint.sh

# 设置noVNC首页
RUN cp /usr/share/novnc/vnc.html /usr/share/novnc/index.html

# 使启动脚本可执行
RUN chmod +x /entrypoint.sh

# 暴露默认端口（可通过环境变量覆盖）
EXPOSE ${NOVNC_PORT:-6901} ${VNC_PORT:-5901}

# 设置环境变量默认值
ENV VNC_PASSWORD=alpine
ENV NOVNC_PORT=6901
ENV VNC_PORT=5901
ENV DISPLAY_WIDTH=1280
ENV DISPLAY_HEIGHT=720
ENV DISPLAY_DEPTH=24

# 设置容器启动命令
ENTRYPOINT ["/entrypoint.sh"]
