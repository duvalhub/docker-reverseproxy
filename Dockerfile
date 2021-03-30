FROM alpine:3.12.4
ARG WORKDIR=/app
WORKDIR ${WORKDIR}

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

# Install simp_le
COPY /install_docker.sh ./install_docker.sh
RUN chmod +rx install_docker.sh \
    && ./install_docker.sh \
    && rm -f /app/install_docker.sh
# Install Docker CLI
# COPY /install_simp_le.sh /app/install_simp_le.sh
# RUN chmod +rx /app/install_simp_le.sh \
#     && sync \
#     && /app/install_simp_le.sh \
#     && rm -f /app/install_simp_le.sh

ENV DEBUG=false \
    DOCKER_HOST=unix:///var/run/docker.sock \
    NGINX_HOME=/etc/nginx \
    NGINX_PROXY_LABEL=reverseproxy.nginx \
    DEVELOPMENT=false

COPY /app/ ${WORKDIR}/
# COPY /todelete/docker /usr/bin/docker

ENTRYPOINT ["/bin/bash", "entrypoint.sh"]
CMD ["/bin/bash", "start.sh"]