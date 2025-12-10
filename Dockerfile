# 阶段1: 构建器 - 仅准备静态资产
FROM alpine:latest as builder

# 安装临时构建工具（这些不会进入最终镜像）
RUN apk add --no-cache git openssl

# 克隆 noVNC 及其依赖（主要的静态资产）
RUN git clone --depth 1 https://github.com/novnc/noVNC.git /assets/novnc && \
    git clone --depth 1 https://github.com/novnc/websockify /assets/novnc/utils/websockify

# 生成SSL证书
RUN mkdir -p /assets/novnc/utils/ssl && \
    cd /assets/novnc/utils/ssl && \
    openssl req -x509 -nodes -newkey rsa:2048 \
        -keyout self.pem -out self.pem -days 3650 \
        -subj "/C=US/ST=State/L=City/O=Organization/CN=localhost" 2>/dev/null


# 阶段2: 最终运行时镜像
FROM alpine:latest

LABEL org.opencontainers.image.title="Firefox with noVNC and Persistent Storage"
LABEL org.opencontainers.image.description="Firefox browser accessible via noVNC with full data persistence support"
LABEL org.opencontainers.image.licenses="MIT"
LABEL org.opencontainers.image.url="https://github.com/yourusername/firefox-novnc"
LABEL org.opencontainers.image.source="https://github.com/yourusername/firefox-novnc"

# 安装所有运行时依赖
RUN apk add --no-cache \
    firefox \
    xvfb \
    x11vnc \
    supervisor \
    bash \
    fluxbox \
    # 英文字体
    font-misc-misc \
    font-cursor-misc \
    ttf-dejavu \
    ttf-droid \
    ttf-freefont \
    ttf-liberation \
    ttf-inconsolata \
    # 工具
    file \
    findutils \
    coreutils \
    && rm -rf /var/cache/apk/*

# 设置英文语言环境
RUN apk add --no-cache locales \
    && echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen \
    && echo "en_GB.UTF-8 UTF-8" >> /etc/locale.gen \
    && locale-gen en_US.UTF-8 en_GB.UTF-8 \
    && rm -rf /var/cache/apk/*

# 创建必要的目录结构
RUN mkdir -p /var/log/supervisor /etc/supervisor/conf.d /root/.vnc

# 创建数据存储目录结构
RUN mkdir -p /data \
    && mkdir -p /data/downloads \
    && mkdir -p /data/bookmarks \
    && mkdir -p /data/cache \
    && mkdir -p /data/config \
    && mkdir -p /data/tmp \
    && chmod -R 777 /data

# 从构建器阶段复制准备好的静态资产
COPY --from=builder /assets/novnc /opt/novnc

# 复制配置文件
COPY supervisord.conf /etc/supervisor/supervisord.conf
COPY start.sh /usr/local/bin/start.sh
COPY init-storage.sh /usr/local/bin/init-storage.sh
COPY backup.sh /usr/local/bin/backup.sh
COPY restore.sh /usr/local/bin/restore.sh
RUN chmod +x /usr/local/bin/*.sh

# 设置noVNC默认页面
RUN echo '<!DOCTYPE html><html><head><meta http-equiv="refresh" content="0;url=vnc.html"><title>Firefox noVNC</title></head><body><p>Redirecting to noVNC...</p></body></html>' > /opt/novnc/index.html

# 创建Firefox配置文件模板
RUN mkdir -p /etc/firefox/template && \
    cat > /etc/firefox/template/prefs.js << 'EOF'
// Firefox preferences for containerized environment
user_pref("browser.cache.disk.parent_directory", "/data/cache");
user_pref("browser.download.dir", "/data/downloads");
user_pref("browser.download.folderList", 2);
user_pref("browser.download.useDownloadDir", true);
user_pref("browser.download.viewableInternally.enabledTypes", "");
user_pref("browser.download.manager.addToRecentDocs", false);
user_pref("browser.bookmarks.file", "/data/bookmarks/bookmarks.html");
user_pref("dom.storage.default_quota", 5242880);
user_pref("dom.storage.enabled", true);
user_pref("dom.indexedDB.enabled", true);
user_pref("intl.accept_languages", "en-US, en");
user_pref("font.language.group", "en-US");
user_pref("font.name-list.serif", "DejaVu Serif, Liberation Serif, Times New Roman");
user_pref("font.name-list.sans-serif", "DejaVu Sans, Liberation Sans, Arial");
user_pref("font.name-list.monospace", "DejaVu Sans Mono, Liberation Mono, Courier New");
user_pref("browser.shell.checkDefaultBrowser", false);
user_pref("browser.startup.page", 0);
user_pref("browser.startup.homepage", "about:blank");
user_pref("browser.startup.homepage_override.mstone", "ignore");
user_pref("startup.homepage_welcome_url", "about:blank");
user_pref("startup.homepage_welcome_url.additional", "about:blank");
user_pref("datareporting.healthreport.uploadEnabled", false);
user_pref("datareporting.policy.dataSubmissionEnabled", false);
user_pref("toolkit.telemetry.unified", false);
user_pref("toolkit.telemetry.enabled", false);
user_pref("toolkit.telemetry.server", "data:,");
user_pref("toolkit.telemetry.archive.enabled", false);
user_pref("toolkit.telemetry.bhrPing.enabled", false);
user_pref("toolkit.telemetry.firstShutdownPing.enabled", false);
user_pref("toolkit.telemetry.hybridContent.enabled", false);
user_pref("toolkit.telemetry.newProfilePing.enabled", false);
user_pref("toolkit.telemetry.reportingpolicy.firstRun", false);
user_pref("toolkit.telemetry.shutdownPingSender.enabled", false);
user_pref("toolkit.telemetry.updatePing.enabled", false);
user_pref("app.normandy.enabled", false);
user_pref("app.normandy.api_url", "");
user_pref("app.shield.optoutstudies.enabled", false);
user_pref("browser.ping-centre.telemetry", false);
user_pref("browser.newtabpage.activity-stream.feeds.telemetry", false);
user_pref("browser.newtabpage.activity-stream.telemetry", false);
EOF

# 创建Firefox默认用户配置文件
RUN cat > /etc/firefox/template/user.js << 'EOF'
// User preferences
user_pref("browser.startup.homepage", "about:blank");
user_pref("browser.startup.page", 0);
user_pref("browser.sessionstore.resume_from_crash", false);
user_pref("browser.sessionstore.max_resumed_crashes", 0);
EOF

# 创建默认书签文件
RUN cat > /data/bookmarks/bookmarks.html << 'EOF'
<!DOCTYPE NETSCAPE-Bookmark-file-1>
<!-- This is an automatically generated file. -->
<META HTTP-EQUIV="Content-Type" CONTENT="text/html; charset=UTF-8">
<TITLE>Bookmarks</TITLE>
<H1>Bookmarks Menu</H1>
<DL><p>
    <DT><H3 ADD_DATE="1640995200" LAST_MODIFIED="1640995200">Favorites</H3>
    <DL><p>
        <DT><A HREF="https://www.google.com" ADD_DATE="1640995200">Google</A>
        <DT><A HREF="https://github.com" ADD_DATE="1640995200">GitHub</A>
        <DT><A HREF="https://stackoverflow.com" ADD_DATE="1640995200">Stack Overflow</A>
    </DL><p>
</DL><p>
EOF

# 暴露端口
EXPOSE 7860 5900

# 创建数据卷
VOLUME ["/data"]

# 启动入口
ENTRYPOINT ["/usr/local/bin/start.sh"]
