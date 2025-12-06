# ==================== 第一阶段：构建阶段 ====================
# 此阶段安装所有必要的软件包，用于准备运行文件。
FROM alpine:latest AS builder

# 使用单个RUN指令安装所有包，并立即清理缓存，以最小化该层体积
RUN apk add --no-cache \
    firefox \
    firefox-lang-en \
    libc6-compat \
    xvfb \
    x11vnc \
    jwm \
    novnc \
    websockify \
    ttf-freefont \
    supervisor \
    dumb-init \
    && rm -rf /tmp/* /var/tmp/*

# ==================== 第二阶段：运行阶段 ====================
# 此阶段创建最终的精简镜像，仅包含运行时必要的文件。
FROM alpine:latest AS runner

# 1. 安装最精简的运行时依赖
RUN apk add --no-cache \
    libc6-compat \
    xvfb \
    x11vnc \
    jwm \
    novnc \
    websockify \
    ttf-freefont \
    supervisor \
    dumb-init \
    && rm -rf /tmp/* /var/tmp/*

# 2. 从构建阶段精确复制应用程序文件
# 2.1 复制Firefox
COPY   /usr/lib/firefox /usr/lib/firefox
COPY   /usr/bin/firefox /usr/bin/firefox
# 2.2 复制glibc兼容库（Alpine运行Firefox的关键）
COPY   /usr/glibc-compat /usr/glibc-compat
COPY   /lib/ld-linux-x86-64.so.2 /lib/
# 2.3 复制noVNC核心文件（避免复制整个目录）
COPY   /usr/share/novnc/vnc*.html /usr/share/novnc/
COPY   /usr/share/novnc/vnc*.js /usr/share/novnc/
COPY   /usr/share/novnc/core /usr/share/novnc/core
COPY   /usr/share/novnc/vendor /usr/share/novnc/vendor
COPY   /usr/libexec/novnc/utils/launch.sh /usr/libexec/novnc/utils/

# 3. 创建非root用户和其家目录
# 重点：这里只创建目录结构，具体挂载在容器运行时决定
RUN adduser -D -u 1000 firefox-user \
    && mkdir -p /home/firefox-user/.mozilla \
    && mkdir -p /home/firefox-user/Downloads \
    && chown -R firefox-user:firefox-user /home/firefox-user

# 4. 复制配置文件
# 4.1 复制Supervisor配置 (需提前在构建上下文中准备好supervisord.conf)
COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf
# 4.2 复制JWM窗口管理器配置 (需提前准备好jwmrc文件)
COPY jwmrc /etc/jwm/jwmrc

# 5. 设置健康检查，验证noVNC服务是否就绪
HEALTHCHECK --interval=30s --timeout=10s --start-period=30s --retries=3 \
    CMD wget --no-verbose --tries=1 --spider http://localhost:6080/ || exit 1

# 6. 设置工作目录、用户和端口
WORKDIR /home/firefox-user
USER firefox-user
EXPOSE 6080

# 7. 使用dumb-init作为入口点，由Supervisor管理进程
ENTRYPOINT ["dumb-init", "--"]
CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf"]
