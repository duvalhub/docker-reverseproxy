#!/bin/bash
set -e

#################
# Source Utils
#################

source functions.sh
source letsencrypt_service --source-only

#################
# Functions
#################
remove_links() {
    log_debug "Removing all symbolic links..."
    for symlinked_domain in /etc/nginx/certs/*.crt; do
        [[ -L "$symlinked_domain" ]] || continue

        symlinked_domain="${symlinked_domain##*/}"
        symlinked_domain="${symlinked_domain%*.crt}"

        for extension in .crt .key .dhparam.pem .chain.pem; do
            local file="${symlinked_domain}${extension}"
            if [[ -n "${file// }" ]] && [[ -L "/etc/nginx/certs/${file}" ]]; then
                log_debug "Removing /etc/nginx/certs/${file}"
                rm -f "/etc/nginx/certs/${file}"
            fi
        done

    done
    log_debug "Symbolic links all removed."

}

create_links() {
    log_info "Generating links..."
    for service in "${LETSENCRYPT_CONTAINERS[@]}"; do
        log_info "Creating SSL link between '$service' and self-signed..."
        service_var="LETSENCRYPT_"$service"_HOST"
        host="${!service_var}"
        cert_link="$path_to_certs/$host.crt"
        key_link="$path_to_certs/$host.key"
        create_link "$default_cert" "$path_to_certs/$host.crt"
        create_link "$default_key" "$path_to_certs/$host.key"
    done
}

#################
# Begin
#################
log_debug "Sourcing service data..."
service_data="$1"
source "$service_data"

path_to_certs="$NGINX_HOME/certs"
default_cert="default.crt"
default_key="default.key"
default_pem="dhparam.pem"

remove_links
create_links