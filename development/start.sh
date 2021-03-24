#!/bin/bash
set -e

declare -i waitTime="${1:-15}"

declare -r image="d-g-s"
declare -r mount_path="$(pwd)/mounts"
declare -a mounts=( certs conf.d html vhost.d )

rm -rf "$mount_path"

for m in ${mounts[*]}; do
    mkdir -p "$mount_path/$m"
done

docker stop dgs || true &
docker stop nginx || true

docker run --name nginx -d --rm \
-v $(pwd)/mounts/conf.d:/etc/nginx/conf.d -v $(pwd)/mounts/certs:/etc/nginx/certs -v $(pwd)/mounts/vhost.d:/etc/nginx/vhost.d -v $(pwd)/mounts/html:/usr/share/nginx/html \
-p 80:80 -p 443:443 \
--network reverseproxy \
-l reverseproxy.nginx -it nginx

docker build -t "$image" .

docker run --rm --name dgs \
-v /var/run/docker.sock:/var/run/docker.sock -v $(pwd)/mounts/conf.d:/etc/nginx/conf.d -v $(pwd)/mounts/certs:/etc/nginx/certs -v $(pwd)/mounts/vhost.d:/etc/nginx/vhost.d -v $(pwd)/mounts/html:/usr/share/nginx/html \
-e DEBUG=true -e DEVELOPMENT=true -e WAIT_TIME=$waitTime \
-it "$image"
