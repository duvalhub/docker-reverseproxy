#!/bin/bash
set -e

declare -i waitTime="${1:-15}"

# declare -r context="${2:-default}"

# docker context use "$context"


declare -r mount_path="${2:-$(pwd)/mounts}"
declare -r image="d-g-s"
declare -a mounts=( certs conf.d html vhost.d )

# rm -rf "$mount_path"

# for m in ${mounts[*]}; do
    # mkdir -p "$mount_path/$m"
# done

docker stop dgs || true &
docker stop nginx || true

docker run --name nginx -d --rm \
-v $mount_path/conf.d:/etc/nginx/conf.d -v $mount_path/certs:/etc/nginx/certs -v $mount_path/vhost.d:/etc/nginx/vhost.d -v $mount_path/html:/usr/share/nginx/html \
-p 80:80 -p 443:443 \
--network reverseproxy \
-l reverseproxy.nginx -it nginx

docker build -t "$image" .

docker run --rm --name dgs \
-v /var/run/docker.sock:/var/run/docker.sock -v $mount_path/conf.d:/etc/nginx/conf.d -v $mount_path/certs:/etc/nginx/certs -v $mount_path/vhost.d:/etc/nginx/vhost.d -v $mount_path/html:/usr/share/nginx/html \
-e DEBUG=true -e DEVELOPMENT=true -e WAIT_TIME=$waitTime -e ACME_CA_URI_BK="https://acme-staging-v02.api.letsencrypt.org/directory" \
-it "$image"
