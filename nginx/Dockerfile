##############################
# Build the NGINX-build image.
FROM debian:bookworm-slim

# Set default ports.
ENV HTTP_PORT 80
ENV HTTPS_PORT 443
ENV RTMP_PORT 1935

RUN apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        curl \
        ffmpeg \
        gettext-base \
        nginx \
        libnginx-mod-rtmp \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Add NGINX path, config and static files.
COPY nginx.conf /etc/nginx/nginx.conf.template
RUN mkdir -p /opt/data /www
COPY static /www/static

EXPOSE 1935
EXPOSE 80

CMD envsubst "$(env | sed -e 's/=.*//' -e 's/^/\$/g')" < \
  /etc/nginx/nginx.conf.template > /etc/nginx/nginx.conf && \
  nginx -g "daemon off;"
