FROM alpine:latest

RUN apk add --no-cache \
    firefox \
    firefox-lang-en \
    libc6-compat \
    xvfb \
    x11vnc \
    novnc \
    websockify \
    jwm \
    supervisor \
    dumb-init \
    ttf-freefont \
    busybox-extras \
    && rm -rf /tmp/* /var/tmp/* \
    && ln -s /usr/share/novnc/vnc.html /usr/share/novnc/index.html 2>/dev/null || true

RUN adduser -D -u 1000 firefox-user \
    && mkdir -p /home/firefox-user/.mozilla \
    && mkdir -p /home/firefox-user/Downloads \
    && chown -R firefox-user:firefox-user /home/firefox-user

COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf
COPY jwmrc /etc/jwm/jwmrc

# 修改点1：健康检查端口改为 7860
HEALTHCHECK --interval=30s --timeout=10s --start-period=30s --retries=3 \
    CMD wget --no-verbose --tries=1 --spider http://localhost:7860/ || exit 1

# 修改点2：声明暴露的端口改为 7860
EXPOSE 7860

WORKDIR /home/firefox-user
USER firefox-user

ENTRYPOINT ["dumb-init", "--"]
CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf"]
