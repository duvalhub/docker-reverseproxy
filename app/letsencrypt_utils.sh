#!/bin/bash -e
generate_lets_encrypt_service_data() {
    local services="$1"
    local destination="$2"
    local letsencrypt_services=()
    while IFS=$'\t' read -r name host; do
        letsencrypt_services+=( "$(echo "$name" | sed 's/-/_/g');$host" )
    done < <(cat "$services" | jq -r '. | [.name,.host] | @tsv')

    echo "LETSENCRYPT_CONTAINERS=(" > "$destination"
    for entry in ${letsencrypt_services[@]}; do
        local name=$(echo "$entry" | cut -d';' -f1)
        printf "\t'$name'\n" >> "$destination"
    done
    echo ")" >> "$destination"

    for entry in ${letsencrypt_services[@]}; do
        local name=$(echo "$entry" | cut -d';' -f1)
        local host=$(echo "$entry" | cut -d';' -f2)
        printf "LETSENCRYPT_"$name"_HOST=('"$host"')\n" >> "$destination"
    done
}