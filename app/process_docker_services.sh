#!/bin/bash -e

##########################
# Parameters
##########################
usage() {
    echo "$0 [OPTIONS]"
    return 1
}
force=false
while [[ $# -gt 0 ]]; do
    key="$1"
    case $key in
        --force) force="true"; shift;;
        *) usage; exit 1 ;;
    esac
done

# if [ -z "$name" ] || [ -z "$dns" ] || [ -z "$destination" ]; then
#     echo "Missing required arguments"
#     usage
#     return 1
# fi

##########################
# Variable
##########################
export DOCKER_HOST=unix:///var/run/docker.sock
export PREVIOUS_SERVICES="services.txt"
export SSL_CERTIFICATES="$WORKDIR/nginx/certs"

##########################
# Source Utils
##########################
source functions.sh
source nginx_utils.sh
source letsencrypt_utils.sh

##########################
# Functions
##########################
process_services() {
    local data="$1"
    if [ -z "$data" ]; then
        read data
    fi
    if [[ -z "$data" ]]; then
        log_error "Services data is empty."
        return 1
    fi
    echo "$data" | jq -r '.[] | select(.Spec.Labels | has("reverseproxy.host")) | {name: .Spec.Name, host: .Spec.Labels."reverseproxy.host"}'
}

process_ssl_services() {
    local data="$1"
    if [ -z "$data" ]; then
        read data
    fi
    if [[ -z "$data" ]]; then
        log_error "Services data is empty."
        return 1
    fi

    echo "$data" | jq -r '.[] | select(.Spec.Labels | has("reverseproxy.host")) | select(.Spec.Labels | has("reverseproxy.ssl")) | {name: .Spec.Name, host: .Spec.Labels."reverseproxy.host"}'
}

evaluate_state() {
    local current_services="$(mktemp)"
    local previous_services="previous-docker-services.json"
    local nginx_conf="$WORKDIR/nginx/conf.d/default.conf"

    docker_list_services | process_services > "$current_services"

    if [ "$force" = true ] || [ ! -f "$previous_services" ] || ! diff -q "$current_services" "$previous_services" ; then
        log_info "Reloading Nginx State."
        > "$nginx_conf"
        generate_nginx_conf "$current_services" "$nginx_conf"
        mv "$current_services" "$previous_services"
        reload_nginx
    else
        log_info "Docker State didn't changed. Skipped"
    fi
}

evaluate_ssl_state() {
    local current="$(mktemp)"
    local previous="previous_letsencrypt_service_data"
    local letsencrypt_service_data="letsencrypt_service_data"

    docker_list_services | process_ssl_services > "$current"

    if [ "$force" = true ] || [ ! -f "$previous" ] || ! diff -q "$current" "$previous" ; then
        log_info "Reloading Ssl State."
        # generate_nginx_conf "$current" "$nginx_conf"
        generate_lets_encrypt_service_data "$current" "$letsencrypt_service_data"
        ./letsencrypt_fake.sh "$letsencrypt_service_data"
        mv "$current" "$previous"
        # return 0
    else
        log_info "Docker SSL State didn't changed. Skipped"
        # return 1
    fi
}

##########################
# Begin
##########################
evaluate_state
evaluate_ssl_state
evaluate_state
