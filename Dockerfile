# ==================== 第一阶段：构建阶段 ====================
FROM alpine:latest AS builder

# 安装所有必要软件包
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
    # 用于查找文件的工具
    findutils \
    && rm -rf /tmp/* /var/tmp/*

# **关键步骤：列出并验证需要复制的关键文件路径**
# 这步不是构建必须，但可以留作调试。在实际Dockerfile中，你需要根据查询结果调整下方的COPY指令。
# RUN find /usr -name "*firefox*" -type f 2>/dev/null | head -20
# RUN find /usr -name "launch.sh" -type f 2>/dev/null
# RUN ls -la /lib/ld-linux* 2>/dev/null || true

# ==================== 第二阶段：运行阶段 ====================
FROM alpine:latest AS runner

# 安装运行时依赖（与builder阶段基本一致，但可以更精简）
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

# **修正后的COPY指令（基于Alpine包常见路径）**
# 1. 复制Firefox
# 注意：Alpine的firefox可能是一个直接可执行的包，不一定有独立的/usr/lib/firefox目录。
# 如果find查询发现没有/usr/lib/firefox，这行应该注释掉。
COPY   /usr/lib/firefox /usr/lib/firefox
# 确保可执行文件存在。如果/usr/bin/firefox就是主程序，这行保留。
COPY   /usr/bin/firefox /usr/bin/firefox

# 2. 复制glibc兼容库 - 重点修正
# libc6-compat不会提供/usr/glibc-compat目录，而是将文件装在/lib和/usr/lib。
# 你需要复制的是具体的库文件，而不是整个目录。
# 首先，复制关键的解释器（loader），这是Firefox在Alpine上运行所必需的。
# 使用`ls`命令先确认路径，例如可能是 `/lib/ld-linux-x86-64.so.2` 或 `/lib/ld-musl-x86-64.so.1`。
COPY   /lib/ld-linux-x86-64.so.2 /lib/
# 其次，复制libc6-compat安装的其他兼容库。一个安全的方法是复制整个/lib目录下的相关文件（但这可能略大）。
# 更精确的做法是只复制firefox依赖的库，但这需要分析。作为起点，可以尝试：
COPY   /lib/libc.so.6 /lib/
COPY   /lib/libm.so.6 /lib/
COPY   /lib/libpthread.so.0 /lib/
COPY   /lib/librt.so.1 /lib/
COPY   /lib/libdl.so.2 /lib/
COPY   /lib/libresolv.so.2 /lib/
# 如果构建还失败，可能需要从/usr/lib复制更多库，或者简单地将整个/lib和/usr/lib复制过来（不推荐，体积大）。

# 3. 复制noVNC
# 根据find查询结果，调整以下路径。在Alpine中，novnc通常安装在 /usr/share/novnc/
COPY   /usr/share/novnc /usr/share/novnc
# launch.sh 脚本可能在 /usr/share/novnc/utils/launch.sh
COPY   /usr/share/novnc/utils/launch.sh /usr/share/novnc/utils/launch.sh

# ... 后面的步骤（创建用户、复制配置文件、设置健康检查等）保持不变 ...
# 3. 创建非root用户和其家目录
RUN adduser -D -u 1000 firefox-user \
    && mkdir -p /home/firefox-user/.mozilla \
    && mkdir -p /home/firefox-user/Downloads \
    && chown -R firefox-user:firefox-user /home/firefox-user

# 4. 复制配置文件 (supervisord.conf, jwmrc 需要你提前准备在构建上下文中)
COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf
COPY jwmrc /etc/jwm/jwmrc

# 5. 设置健康检查
HEALTHCHECK --interval=30s --timeout=10s --start-period=30s --retries=3 \
    CMD wget --no-verbose --tries=1 --spider http://localhost:6080/ || exit 1

WORKDIR /home/firefox-user
USER firefox-user
EXPOSE 6080

ENTRYPOINT ["dumb-init", "--"]
CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf"]
