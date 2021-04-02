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

# Install Docker CLI
COPY /install_docker.sh ./install_docker.sh
RUN chmod +rx install_docker.sh \
    && ./install_docker.sh \
    && rm -f /app/install_docker.sh

COPY /app/ ${WORKDIR}/

ENTRYPOINT ["/bin/bash", "entrypoint.sh"]
CMD ["/bin/bash", "start.sh"]