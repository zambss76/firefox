# 第一阶段：构建阶段 (Builder)
FROM alpine:latest AS builder

# 安装所有必要的包
RUN apk add --no-cache \
    firefox-esr \
    xvfb \
    x11vnc \
    novnc \
    websockify \
    supervisor \
    bash \
    ttf-dejavu \
    && rm -rf /var/cache/apk/*

# 第二阶段：运行阶段 (Runner)
FROM alpine:latest

# 安装最基础的运行时依赖
RUN apk add --no-cache \
    bash \
    libstdc++ \
    gcompat \
    ttf-dejavu \
    && rm -rf /var/cache/apk/*

# 从 builder 阶段精确复制应用程序和库文件
# 1. 复制 Firefox
COPY --from=builder /usr/bin/firefox-esr /usr/bin/
COPY --from=builder /usr/lib/firefox-esr/ /usr/lib/firefox-esr/
COPY --from=builder /usr/share/firefox-esr/ /usr/share/firefox-esr/

# 2. 复制 Xvfb 和 x11vnc
COPY --from=builder /usr/bin/xvfb-run /usr/bin/
COPY --from=builder /usr/bin/xvfb /usr/bin/
COPY --from=builder /usr/bin/x11vnc /usr/bin/
COPY --from=builder /usr/lib/libvncserver.so* /usr/lib/

# 3. 复制 noVNC 和 websockify
COPY --from=builder /usr/share/novnc/ /usr/share/novnc/
COPY --from=builder /usr/bin/websockify /usr/bin/
COPY --from=builder /usr/lib/python3.11/site-packages/websockify/ /usr/lib/python3.11/site-packages/websockify/

# 4. 【关键修正】复制 Supervisor 的必要文件
# 复制可执行文件
COPY --from=builder /usr/bin/supervisord /usr/bin/
# 复制 Python 包目录，这是 supervisor 的核心
COPY --from=builder /usr/lib/python3.11/site-packages/supervisor/ /usr/lib/python3.11/site-packages/supervisor/
# 复制默认配置文件（如果存在）
COPY --from=builder /etc/supervisord.conf /etc/supervisord.conf 2>/dev/null || echo “默认 supervisord.conf 不存在，将使用项目中的配置”

# 5. 复制可能需要的其他库（如果运行时报错缺失，需要回来补充）
COPY --from=builder /usr/lib/ /usr/lib/

# 创建用户、目录和符号链接
RUN adduser -D -u 1000 firefoxuser \
    && mkdir -p /home/firefoxuser/.mozilla/firefox/default-release \
    && mkdir -p /etc/supervisor/conf.d \ # 确保配置目录存在
    && chown -R firefoxuser:firefoxuser /home/firefoxuser \
    && ln -s /usr/share/novnc/vnc.html /usr/share/novnc/index.html

USER firefoxuser
WORKDIR /home/firefoxuser

# 复制你项目中的配置文件（这会将我们上面的默认配置覆盖）
COPY --chown=firefoxuser:firefoxuser supervisord.conf /etc/supervisor/conf.d/
COPY --chown=firefoxuser:firefoxuser refresh.sh ./
COPY --chown=firefoxuser:firefoxuser firefox-prefs.js ./
RUN chmod +x ./refresh.sh

EXPOSE 7860
CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf"]
