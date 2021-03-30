#!/bin/bash
# bash development/start.sh --fresh-start --development

set -e
declare -r nginx_name="nginx"
declare -r dgs_name="dgs"
declare -r image="d-g-s"
declare -i wait="15"
declare mount_path="$(pwd)/mounts"
declare fresh_start=false
declare development=false
declare staging=false
usage() {
    echo "You passed bad params"
    exit 1
}
while [[ $# -gt 0 ]]; do
case "$1" in
    --wait) wait="$2"; shift; shift;;
    --mounth-path) mount_path="$2"; shift; shift;;
    --fresh-start) fresh_start="true"; shift;;
    --development) development="true"; shift;;
    --staging) staging="true"; shift;;
    *) usage; return 1 ;;
esac
done

declare -a mounts=( certs conf.d html vhost.d )

if [[ "$fresh_start" == true ]]; then
    rm -rf "$mount_path"
    for m in ${mounts[*]}; do
        mkdir -p "$mount_path/$m"
    done
fi

docker stop "$dgs_name" || true &
docker stop "$nginx_name" || true

docker run --name "$nginx_name" -d --rm \
-v $mount_path/conf.d:/etc/nginx/conf.d -v $mount_path/certs:/etc/nginx/certs -v $mount_path/vhost.d:/etc/nginx/vhost.d -v $mount_path/html:/usr/share/nginx/html \
-p 80:80 -p 443:443 \
--network reverseproxy \
-l reverseproxy.nginx -it nginx

docker build -t "$image" .

declare acme_ca_staging=""
if [[ "$staging" == true ]]; then
    acme_ca_staging='-e ACME_CA_URI="https://acme-staging-v02.api.letsencrypt.org/directory"'
fi

declare -r param="-e DEBUG=true -e DEVELOPMENT="$development" -e WAIT_TIME=$wait $acme_ca_staging"
echo "Running container with '$param'"
sleep 3

until [ "`docker inspect -f {{.State.Running}} $nginx_name`"=="true" ]; do
    echo "Waiting for $nginx_name to be up and running..."
    sleep 1;
done;
docker run --rm --name "$dgs_name" \
-v /var/run/docker.sock:/var/run/docker.sock -v $mount_path/conf.d:/etc/nginx/conf.d -v $mount_path/certs:/etc/nginx/certs -v $mount_path/vhost.d:/etc/nginx/vhost.d -v $mount_path/html:/usr/share/nginx/html \
$param \
-it "$image"
