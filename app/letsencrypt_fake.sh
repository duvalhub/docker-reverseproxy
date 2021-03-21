#!/bin/bash -e

service_data="$1"
source "$service_data"

# echo "$LETSENCRYPT_CONTAINERS"
path_to_certs="$WORKDIR/nginx/certs"
default_cert="default.crt"
default_key="default.key"

for service in "${LETSENCRYPT_CONTAINERS[@]}"; do
    service_var="LETSENCRYPT_"$service"_HOST"
    host="${!service_var}"
    cert_link="$path_to_certs/$host.crt"
    key_link="$path_to_certs/$host.key"
    [[ -f "$cert_link" ]] && rm -f "$cert_link"
    [[ -f "$key_link" ]] && rm -f "$key_link"
    ln -s "$default_cert" "$path_to_certs/$host.crt"
    ln -s "$default_key" "$path_to_certs/$host.key"
done

