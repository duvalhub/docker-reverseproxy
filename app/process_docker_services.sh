#!/bin/bash 
set -e

##########################
# Parameters
##########################
usage() {
    echo "$0 [OPTIONS]"
    return 1
}
force=false
development=false
while [[ $# -gt 0 ]]; do
    key="$1"
    case $key in
        --force) force="true"; shift;;
        --development) development="true"; shift;;
        *) usage; exit 1 ;;
    esac
done

##########################
# Source Utils
##########################
source functions.sh
source nginx_utils.sh
source letsencrypt_service --source-only

##########################
# Functions
##########################
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
process_services() {
    local data="$1"
    if [ -z "$data" ]; then
        read data
    fi
    if [[ -z "$data" ]]; then
        log_error "Services data is empty." >&2
        return 1
    fi
    echo "$data" | jq -e -r '.[] | select(.Spec.Labels | has("reverseproxy.host")) | {name: .Spec.Name, host: .Spec.Labels."reverseproxy.host", ssl: .Spec.Labels."reverseproxy.ssl"}' || { 
        log_error "Failed to parse Services state"
        return 1
    }
}

process_ssl_services() {
    local data="$1"
    if [ -z "$data" ]; then
        read data
    fi
    if [[ -z "$data" ]]; then
        log_error "Services data is empty." >&2
        return 1
    fi

    echo "$data" | jq -r '.[] | select(.Spec.Labels | has("reverseproxy.host")) | select(.Spec.Labels | has("reverseproxy.ssl")) | {name: .Spec.Name, host: .Spec.Labels."reverseproxy.host"}' || { 
        log_error "Failed to parse SSL state" >&2
        return 1
    }
}

check_service_state() {
    if [ -z "$services_state" ]; then
        log_error "'services_state' variable unset. Fatal error."
        return 1
    fi
    if [ -f "$services_state" ]; then
        log_debug "Service state file found at '$services_state'"
    else
        log_debug "Service state not found. Generating a fresh one into '$services_state'"
        docker_list_services "$services_state"
    fi    
}

evaluate_state() {
    log_info "[SERVICE] Evaluation if Nginx Configuration has to be reload..."
    check_service_state
    local service_state_processed="$services_state.processed"
    log_debug "[SERVICE] Processing Service State to generate Nginx Conf..."
    cat "$services_state" | process_services > "$service_state_processed"
    log_debug "[SERVICE] Service state processed and located at '$service_state_processed'. Ready to generate Nginx Configuration..."
    local current=nginx.conf.new
    local nginx_conf="$NGINX_HOME/conf.d/default.conf"

    generate_nginx_conf "$service_state_processed" "$current"

    if [ ! -f "$nginx_conf" ] || ! diff -q "$nginx_conf" "$current" > /dev/null ; then
        log_info "[SERVICE] Nginx Configuration changed. Reloading Nginx..."
        mv "$current" "$nginx_conf"
        reload_nginx
    else
        log_info "[SERVICE] Nginx Configuration didn't changed. Nginx Reload skipped."
    fi
    rm -f "$current"
}

evaluate_ssl_state() {
    log_info "[SSL] Evaluation if SSL Certificates have to be generate..."
    check_service_state
    local service_state_processed="$services_state.processed"
    local letsencrypt_service_data="letsencrypt_service_data"
    cat "$services_state" | process_ssl_services > "$service_state_processed"
    generate_lets_encrypt_service_data "$service_state_processed" "$letsencrypt_service_data"
    local letsencrypt_service="update_certs"
    "$letsencrypt_service" "$letsencrypt_service_data"
    evaluate_state
}

##########################
# Begin
##########################
log_info "Evaluating if Nginx conf has to be reload and/or if SSL Certs has to be generated..."
services_state="docker-services.json"
log_info "Retrieving Docker Service state into '$services_state'..."
docker_list_services "$services_state"
log_info "Evaluating Nginx Conf..."
evaluate_state
log_info "Evaluating SSL Certs..."
evaluate_ssl_state
log_info "Evaluation done succesfully"
