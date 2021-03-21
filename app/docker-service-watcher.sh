#!/bin/bash -e
echo "Deprecated"
# ##########################
# # Parameters
# ##########################
# usage() {
#     echo "$0 [OPTIONS]"
#     return 1
# }
# force=false
# while [[ $# -gt 0 ]]; do
#     key="$1"
#     case $key in
#         --force) force="true"; shift;;
#         *) usage; exit 1 ;;
#     esac
# done

# # if [ -z "$name" ] || [ -z "$dns" ] || [ -z "$destination" ]; then
# #     echo "Missing required arguments"
# #     usage
# #     return 1
# # fi

# ##########################
# # Variable
# ##########################
# export DOCKER_HOST=unix:///var/run/docker.sock
# export PREVIOUS_SERVICES="services.txt"
# export SSL_CERTIFICATES="$WORKDIR/nginx/certs"

# ##########################
# # Source Utils
# ##########################
# source functions.sh
# source nginx_utils.sh

# ##########################
# # Functions
# ##########################
# process_services() {
#     local data="$1"
#     if [ -z "$data" ]; then
#         read data
#     fi
#     if [[ -z "$data" ]]; then
#         log_error "Services data is empty."
#         return 1
#     fi
#     echo "$data" | jq -r '.[] | select(.Spec.Labels | has("reverseproxy.host")) | {name: .Spec.Name, host: .Spec.Labels."reverseproxy.host"}'
# }

# ##########################
# # Begin
# ##########################
# current_services="$(mktemp)"
# previous_services="previous-docker-services.json"
# nginx_conf="$WORKDIR/nginx/conf.d/default.conf"

# docker_list_services | process_services > "$current_services"

# if [ "$force" = true ] || [ ! -f "$previous_services" ] || ! diff -q "$current_services" "$previous_services" ; then
#     log_info "Reloading Nginx State."
#     > "$nginx_conf"
#     generate_nginx_conf "$current_services" "$nginx_conf"
#     mv "$current_services" "$previous_services"
#     reload_nginx
# else
#     log_info "Docker State didn't changed. Skipped"
# fi

# docker_list_services | jq '.' > services.json
