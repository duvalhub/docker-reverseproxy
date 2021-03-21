#!/bin/bash -e
echo "Sourcing service data..."
service_data="$1"
source "$service_data"

path_to_certs="$WORKDIR/nginx/certs"
default_cert="default.crt"
default_key="default.key"
default_pem="dhparam.pem"

all_links=$(ls "$path_to_certs"|grep -v -e "$default_cert" -e "$default_key" -e "$default_pem") || all_links=""

echo "Clearing links..."
for link in $all_links; do
    echo "Removing link '$link'"
    rm -f "$path_to_certs/$link"
done

echo "Generating links..."
for service in "${LETSENCRYPT_CONTAINERS[@]}"; do
    echo "Enabling '$service"
    service_var="LETSENCRYPT_"$service"_HOST"
    host="${!service_var}"
    cert_link="$path_to_certs/$host.crt"
    key_link="$path_to_certs/$host.key"
    ln -s "$default_cert" "$path_to_certs/$host.crt"
    ln -s "$default_key" "$path_to_certs/$host.key"
done

