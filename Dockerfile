FROM alpine:3.12.4

# Install packages required by the image
RUN apk add --update \
        bash \
        ca-certificates \
        coreutils \
        curl \
        jq \
        openssl \
    && rm /var/cache/apk/*

# ARG USER=app
# RUN addgroup -S $USER && adduser -S $USER -G $USER
# USER $USER
# ARG HOME=/home/$USER
# WORKDIR $HOME
WORKDIR /app

ENV DEBUG=false \
    DOCKER_HOST=unix:///var/run/docker.sock

COPY app/entrypoint.sh ./
COPY app/watcher.sh ./
COPY app/process_docker_services.sh ./
COPY app/functions.sh ./
COPY app/nginx_utils.sh ./
COPY app/letsencrypt_utils.sh ./

ENTRYPOINT ["/bin/bash", "entrypoint.sh"]
CMD ["/bin/bash", "watcher.sh"]