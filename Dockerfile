FROM alpine:3.20

RUN apk add --no-cache \
    nginx \
    supervisor \
    curl \
    python3 \
    jq \
    && rm -rf /var/cache/apk/*

# Install latest Trivy (official script, defaults to latest)
RUN curl -sfL https://raw.githubusercontent.com/aquasecurity/trivy/main/contrib/install.sh | sh -s -- -b /usr/local/bin

# Copy configs and scripts
COPY supervisord.conf /etc/supervisord.conf
COPY nginx.conf /etc/nginx/http.d/default.conf
COPY entrypoint.sh /entrypoint.sh
COPY default_images.list /app/default_images.list
COPY app/ /app/
COPY html/index.html /usr/share/nginx/html/index.html

RUN chmod +x /entrypoint.sh /app/*.sh \
    && mkdir -p /data/scans /var/log/supervisor \
    && chown -R nginx:nginx /usr/share/nginx/html

EXPOSE 80

ENTRYPOINT ["/entrypoint.sh"]