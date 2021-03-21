#!/bin/bash

############################
# Logging
############################
log() {
    local level="$1"
    echo "$(date '+%Y-%m-%d %H:%M:%S') [$level] - $2"
}

log_info() {
    log "INFO" "$@"
}

log_warn() {
    log "WARNING" "$@"
}

log_error() {
    log "ERROR" "$@"
}

log_debug() {
    if [[ -n "$LOG_LEVEL" && "$LOG_LEVEL" = "DEBUG" ]]; then
        log "DEBUG" "$@"
    fi
}

############################
# Docker API
############################
docker_api() {
    local scheme
    local curl_opts=(-s)
    local method=${2:-GET}
    # data to POST
    if [[ -n "${3:-}" ]]; then
        curl_opts+=(-d "$3")
    fi
    if [[ -z "$DOCKER_HOST" ]];then
        echo "Error DOCKER_HOST variable not set" >&2
        return 1
    fi
    if [[ $DOCKER_HOST == unix://* ]]; then
        curl_opts+=(--unix-socket ${DOCKER_HOST#unix://})
        scheme='http://localhost'
    else
        scheme="http://${DOCKER_HOST#*://}"
    fi
    [[ $method = "POST" ]] && curl_opts+=(-H 'Content-Type: application/json')
    curl "${curl_opts[@]}" -X${method} ${scheme}$1
}

docker_list_services() {
    local command="/services"
    docker_api "$command"
}

docker_exec() {
    local id="${1?missing id}"
    local cmd="${2?missing command}"
    local data=$(printf '{ "AttachStdin": false, "AttachStdout": true, "AttachStderr": true, "Tty":false,"Cmd": %s }' "$cmd")
    exec_id=$(docker_api "/containers/$id/exec" "POST" "$data" | jq -r .Id)
    if [[ -n "$exec_id" && "$exec_id" != "null" ]]; then
        docker_api /exec/$exec_id/start "POST" '{"Detach": false, "Tty":false}'
    else
        echo "$(date "+%Y/%m/%d %T"), Error: can't exec command ${cmd} in container ${id}. Check if the container is running." >&2
        return 1
    fi
}

docker_restart() {
    local id="${1?missing id}"
    docker_api "/containers/$id/restart" "POST"
}

docker_kill() {
    local id="${1?missing id}"
    local signal="${2?missing signal}"
    docker_api "/containers/$id/kill?signal=$signal" "POST"
}




function labeled_cid {
    docker_api "/containers/json" | jq -r '.[] | select(.Labels["'"$1"'"])|.Id'
}

function get_nginx_proxy_container {
    local volumes_from
    # First try to get the nginx container ID from the container label.
    local nginx_cid; nginx_cid="$(labeled_cid reverseproxy.nginx_proxy)"

    # If the labeled_cid function dit not return anything ...
    if [[ -z "${nginx_cid}" ]]; then
        # ... and the env var is set, use it ...
        if [[ -n "${NGINX_PROXY_CONTAINER:-}" ]]; then
            nginx_cid="$NGINX_PROXY_CONTAINER"
        # ... else try to get the container ID with the volumes_from method.
        elif [[ $(get_self_cid) ]]; then
            volumes_from=$(docker_api "/containers/$(get_self_cid)/json" | jq -r '.HostConfig.VolumesFrom[]' 2>/dev/null)
            for cid in $volumes_from; do
                cid="${cid%:*}" # Remove leading :ro or :rw set by remote docker-compose (thx anoopr)
                if [[ $(docker_api "/containers/$cid/json" | jq -r '.Config.Env[]' | grep -c -E '^NGINX_VERSION=') = "1" ]];then
                    nginx_cid="$cid"
                    break
                fi
            done
        fi
    fi

    # If a container ID was found, output it. The function will return 1 otherwise.
    [[ -n "$nginx_cid" ]] && echo "$nginx_cid"
}

## Nginx
function reload_nginx {
    # local _docker_gen_container; _docker_gen_container=$(get_docker_gen_container)
    local _nginx_proxy_container; _nginx_proxy_container=$(get_nginx_proxy_container)

    if [[ -n "${_nginx_proxy_container:-}" ]]; then
        echo "Reloading nginx proxy (${_nginx_proxy_container})..."
        docker_exec "${_nginx_proxy_container}" \
            '[ "sh", "-c", "/usr/sbin/nginx -s reload" ]' \
            | sed -rn 's/^.*([0-9]{4}\/[0-9]{2}\/[0-9]{2}.*$)/\1/p'
        [[ ${PIPESTATUS[0]} -eq 1 ]] && echo "$(date "+%Y/%m/%d %T"), Error: can't reload nginx-proxy." >&2
    fi
}
