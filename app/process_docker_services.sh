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
    echo "$data" | jq -r '.[] | select(.Spec.Labels | has("reverseproxy.host")) | {name: .Spec.Name, host: .Spec.Labels."reverseproxy.host", ssl: .Spec.Labels."reverseproxy.ssl"}'
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
    log_info "[SERVICE] Evaluation if Service State Changed..."
    local current="$(mktemp)"
    local previous="previous-docker-services.json"
    local nginx_conf="$WORKDIR/nginx/conf.d/default.conf"

    docker_list_services | process_services > "$current"

    if [ "$force" = true ] || [ ! -f "$previous" ] || ! diff -q "$current" "$previous" > /dev/null ; then
        log_info "[SERVICE] Service State Changed. Reloading Nginx State."
        > "$nginx_conf"
        generate_nginx_conf "$current" "$nginx_conf"
        mv "$current" "$previous"
        reload_nginx
    else
        log_info "[SERVICE] Docker State didn't changed. Skipped"
    fi
    rm -f "$current"
}

evaluate_ssl_state() {
    log_info "[SSL] Evaluation if SSL State Changed..."
    local current="$(mktemp)"
    local previous="previous_letsencrypt_service_data"
    local letsencrypt_service_data="letsencrypt_service_data"

    docker_list_services | process_ssl_services > "$current"

    if [ "$force" = true ] || [ ! -f "$previous" ] || ! diff -q "$current" "$previous" > /dev/null ; then
        log_info "[SSL] SSL State changed. Reload SSL State."
        generate_lets_encrypt_service_data "$current" "$letsencrypt_service_data"
        ./letsencrypt_fake.sh "$letsencrypt_service_data"
        mv "$current" "$previous"
    else
        log_info "[SSL] Docker SSL State didn't changed. Skipped"
    fi

    rm -f "$current"
}

##########################
# Begin
##########################
# evaluate_state || log_error "We crashed while evaluating state"
evaluate_ssl_state || log_error "We crashed while evaluating ssl"
evaluate_state || log_error "We crashed while evaluating state"
