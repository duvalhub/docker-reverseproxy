FROM alpine:3.12.4
ARG WORKDIR=/app
WORKDIR ${WORKDIR}

ENV DEBUG=false \
    DOCKER_HOST=unix:///var/run/docker.sock \
    NGINX_HOME=/etc/nginx \
    DEVELOPMENT=false

# Install packages required by the image
RUN apk add --update \
        bash \
        ca-certificates \
        coreutils \
        curl \
        jq \
        openssl \
    && rm /var/cache/apk/*

# Install simp_le
COPY /install_simp_le.sh /app/install_simp_le.sh
RUN chmod +rx /app/install_simp_le.sh \
    && sync \
    && /app/install_simp_le.sh \
    && rm -f /app/install_simp_le.sh

COPY /app/ ${WORKDIR}/

ENTRYPOINT ["/bin/bash", "entrypoint.sh"]
CMD ["/bin/bash", "watcher.sh"]