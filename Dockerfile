# 阶段1: 构建器 - 仅准备静态资产
FROM alpine:latest as builder

# 安装临时构建工具（这些不会进入最终镜像）
RUN apk add --no-cache git openssl

# 克隆 noVNC 及其依赖（主要的静态资产）
RUN git clone --depth 1 https://github.com/novnc/noVNC.git /assets/novnc && \
    git clone --depth 1 https://github.com/novnc/websockify /assets/novnc/utils/websockify

# （可选）在第一阶段生成SSL证书
RUN mkdir -p /assets/novnc/utils/ssl && \
    cd /assets/novnc/utils/ssl && \
    openssl req -x509 -nodes -newkey rsa:2048 \
        -keyout self.pem -out self.pem -days 3650 \
        -subj "/C=US/ST=State/L=City/O=Organization/CN=localhost" 2>/dev/null


# 阶段2: 最终运行时镜像
FROM alpine:latest

LABEL org.opencontainers.image.title="Lightweight Firefox with noVNC"
LABEL org.opencontainers.image.description="Ultra-lightweight Firefox browser with noVNC web access and VNC password support"
LABEL org.opencontainers.image.licenses="MIT"

# 安装所有运行时依赖（包含中文字体）
RUN apk add --no-cache \
    firefox \
    xvfb \
    x11vnc \
    supervisor \
    bash \
    fluxbox \
    # 基础字体集
    font-misc-misc \
    font-cursor-misc \
    ttf-dejavu \
    # 中文字体
    font-noto \
    font-noto-cjk \
    font-noto-extra \
    font-noto-arabic \
    font-noto-thai \
    font-noto-emoji \
    # 文泉驿中文字体
    font-wqy-zenhei \
    font-wqy-microhei \
    # 其他常用字体
    ttf-droid \
    ttf-freefont \
    ttf-liberation \
    ttf-inconsolata \
    && rm -rf /var/cache/apk/*

# 设置中文语言环境
RUN apk add --no-cache \
    locales \
    && echo "zh_CN.UTF-8 UTF-8" >> /etc/locale.gen \
    && locale-gen zh_CN.UTF-8 \
    && rm -rf /var/cache/apk/*

# 创建必要的目录结构
RUN mkdir -p /var/log/supervisor /etc/supervisor/conf.d /root/.vnc

# 关键优化：从构建器阶段仅复制准备好的静态资产
COPY --from=builder /assets/novnc /opt/novnc

# 复制本地配置文件
COPY supervisord.conf /etc/supervisor/supervisord.conf
COPY start.sh /usr/local/bin/start.sh
RUN chmod +x /usr/local/bin/start.sh

# 设置noVNC默认跳转页面
RUN echo '<html><head><meta http-equiv="refresh" content="0;url=vnc.html"></head><body></body></html>' > /opt/novnc/index.html

# 为Firefox创建配置文件以支持中文显示
RUN mkdir -p /root/.mozilla/firefox/default && \
    echo 'pref("font.name-list.serif.zh-CN", "Noto Serif CJK SC, WenQuanYi Zen Hei, DejaVu Serif");' > /root/.mozilla/firefox/default/prefs.js && \
    echo 'pref("font.name-list.sans-serif.zh-CN", "Noto Sans CJK SC, WenQuanYi Zen Hei, DejaVu Sans");' >> /root/.mozilla/firefox/default/prefs.js && \
    echo 'pref("font.name-list.monospace.zh-CN", "Noto Sans Mono CJK SC, WenQuanYi Zen Hei Mono, DejaVu Sans Mono");' >> /root/.mozilla/firefox/default/prefs.js && \
    echo 'pref("intl.accept_languages", "zh-CN, en-US, en");' >> /root/.mozilla/firefox/default/prefs.js && \
    echo 'pref("font.language.group", "zh-CN");' >> /root/.mozilla/firefox/default/prefs.js

# 创建Firefox默认用户配置文件，避免首次启动向导
RUN echo '{"HomePage":"about:blank","StartPage":"about:blank"}' > /root/.mozilla/firefox/default/user.js

# 暴露端口
EXPOSE 7860 5900

# 声明挂载卷
VOLUME /data

# 启动入口
CMD ["/usr/local/bin/start.sh"]
