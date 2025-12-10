# ============================================================================
# 阶段1: 构建器 - 在Alpine (musl libc) 环境中编译KasmVNC
# ============================================================================
FROM alpine:latest AS builder

# 1. 更新软件源并安装所有编译依赖
# 关键：在Alpine中，部分开发包名称与通用名略有不同。
RUN apk update && apk add --no-cache \
    build-base \
    cmake \
    git \
    # 图形和编码库
    libjpeg-turbo-dev \
    libpng-dev \
    libwebp-dev \
    # X11开发库 (Alpine包名通常以‘-dev’结尾)
    libxtst-dev \
    libx11-dev \
    libxext-dev \
    libxi-dev \
    libxrandr-dev \
    libxfixes-dev \
    libxdamage-dev \
    libxcursor-dev \
    xorgproto \          # 提供X11协议头文件
    # 加密和网络库
    openssl-dev \
    nettle-dev \
    # 构建工具
    libtool \
    automake \
    autoconf \
    pkgconf \           # Alpine中通常叫 pkgconf，不是 pkgconfig
    g++ \
    # 内核头文件（某些低级库需要）
    linux-headers

# 2. 克隆并编译KasmVNC
# 注意：我们已关闭了图形化VIEWER的编译（-DBUILD_VIEWER=OFF），并明确设置安装前缀。
RUN cd /tmp && \
    git clone https://github.com/kasmtech/KasmVNC.git --depth 1 && \
    cd KasmVNC && \
    mkdir build && cd build && \
    # 关键配置：指定Release模式、关闭Viewer、设置安装路径。
    # 在Alpine上，使用默认的编译器和库。
    cmake .. \
        -DCMAKE_BUILD_TYPE=Release \
        -DBUILD_VIEWER=OFF \
        -DCMAKE_INSTALL_PREFIX=/usr/local && \
    # 如果服务器内存较小，可去掉 -j$(nproc) 或改为 -j2
    make -j$(nproc) && \
    make DESTDIR=/opt/kasmvnc install

# 至此，KasmVNC已被安装到 /opt/kasmvnc/usr/local/ 目录下。
# ============================================================================

# 阶段2: 最终运行时镜像
# ============================================================================
FROM alpine:latest

# 镜像元数据
LABEL org.opencontainers.image.title="Firefox with KasmVNC"
LABEL org.opencontainers.image.description="Lightweight Firefox browser accessible via high-performance KasmVNC web client"
LABEL org.opencontainers.image.licenses="MIT"

# 安装所有运行时依赖
RUN apk add --no-cache \
    firefox \
    xvfb \
    supervisor \
    bash \
    fluxbox \
    # 基础字体集
    font-misc-misc \
    font-cursor-misc \
    ttf-dejavu \
    ttf-droid \
    ttf-freefont \
    ttf-liberation \
    ttf-inconsolata \
    # 系统工具
    file \
    findutils \
    coreutils \
    # KasmVNC运行时依赖的X11库
    libjpeg-turbo \
    libpng \
    libwebp \
    libxtst \
    libx11 \
    libxext \
    libxi \
    libxrandr \
    libxfixes \
    libxdamage \
    libxcursor \
    # 网络和安全库
    openssl \
    nettle \
    # 清理缓存以减小镜像体积
    && rm -rf /var/cache/apk/*

# 设置英文语言环境
RUN apk add --no-cache locales \
    && echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen \
    && echo "en_GB.UTF-8 UTF-8" >> /etc/locale.gen \
    && locale-gen en_US.UTF-8 en_GB.UTF-8 \
    && rm -rf /var/cache/apk/*

# 创建必要的目录结构
RUN mkdir -p \
    /var/log/supervisor \
    /etc/supervisor/conf.d \
    /root/.vnc \
    /root/.fluxbox \
    /data \
    /data/downloads \
    /data/bookmarks \
    /data/cache \
    /data/config \
    /data/tmp \
    && chmod -R 777 /data

# 从构建器阶段复制已编译的KasmVNC
COPY --from=builder /opt/kasmvnc/usr/local/ /usr/local/

# 创建KasmVNC的符号链接以便在PATH中直接使用
RUN ln -sf /usr/local/bin/kasmvncserver /usr/bin/ \
    && ln -sf /usr/local/share/kasmvnc /usr/local/share/ \
    && mkdir -p /usr/local/share/kasmvnc/web

# 复制配置文件
COPY supervisord.conf /etc/supervisor/supervisord.conf
COPY start.sh /usr/local/bin/start.sh
COPY init-storage.sh /usr/local/bin/init-storage.sh
COPY backup.sh /usr/local/bin/backup.sh
COPY restore.sh /usr/local/bin/restore.sh
RUN chmod +x /usr/local/bin/*.sh

# 创建Firefox配置模板
RUN mkdir -p /etc/firefox/template && \
    cat > /etc/firefox/template/prefs.js << 'EOF'
// Firefox preferences for containerized environment
user_pref("browser.cache.disk.parent_directory", "/data/cache");
user_pref("browser.download.dir", "/data/downloads");
user_pref("browser.download.folderList", 2);
user_pref("browser.download.useDownloadDir", true);
user_pref("browser.bookmarks.file", "/data/bookmarks/bookmarks.html");
user_pref("dom.storage.default_quota", 5242880);
user_pref("dom.storage.enabled", true);
user_pref("dom.indexedDB.enabled", true);
user_pref("intl.accept_languages", "en-US, en");
user_pref("font.language.group", "en-US");
user_pref("browser.shell.checkDefaultBrowser", false);
user_pref("browser.startup.page", 0);
user_pref("datareporting.healthreport.uploadEnabled", false);
user_pref("toolkit.telemetry.enabled", false);
EOF

# 设置简单的Fluxbox菜单
RUN echo '[begin] (fluxbox)' > /root/.fluxbox/menu && \
    echo '[exec] (Firefox) {firefox}' >> /root/.fluxbox/menu && \
    echo '[exec] (Terminal) {xterm}' >> /root/.fluxbox/menu && \
    echo '[separator]' >> /root/.fluxbox/menu && \
    echo '[exit] (Exit)' >> /root/.fluxbox/menu && \
    echo '[end]' >> /root/.fluxbox/menu

# 暴露网络端口
# KasmVNC RFB协议端口 (用于传统VNC客户端)
EXPOSE 5901
# KasmVNC WebSocket端口 (用于网页客户端访问)
EXPOSE 7860

# 声明数据卷
VOLUME ["/data"]

# 容器启动入口
ENTRYPOINT ["/usr/local/bin/start.sh"
