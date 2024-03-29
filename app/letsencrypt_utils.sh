#!/bin/bash
# shellcheck disable=SC2120

source functions.sh

seconds_to_wait=3600
ACME_CA_URI="${ACME_CA_URI:-https://acme-v02.api.letsencrypt.org/directory}"
DEFAULT_KEY_SIZE=4096
REUSE_ACCOUNT_KEYS="$(lc ${REUSE_ACCOUNT_KEYS:-true})"
REUSE_PRIVATE_KEYS="$(lc ${REUSE_PRIVATE_KEYS:-false})"
MIN_VALIDITY_CAP=7603200
DEFAULT_MIN_VALIDITY=2592000

pushd () {
    command pushd "$@" > /dev/null
}

popd () {
    command popd "$@" > /dev/null
}

function create_link {
    local -r source=${1?missing source argument}
    local -r target=${2?missing target argument}
    if [[ -f "$target" ]] && [[ "$(readlink "$target")" == "$source" ]]; then
      set_ownership_and_permissions "$target"
      log_debug "$target already linked to $source"
      return 1
    else
      ln -sf "$source" "$target" \
        && set_ownership_and_permissions "$target"
    fi
}

function create_links {
    local -r base_domain=${1?missing base_domain argument}
    local -r domain=${2?missing base_domain argument}

    if [[ ! -f "/etc/nginx/certs/$base_domain/fullchain.pem" || \
          ! -f "/etc/nginx/certs/$base_domain/key.pem" ]]; then
        return 1
    fi
    local return_code=1
    create_link "./$base_domain/fullchain.pem" "/etc/nginx/certs/$domain.crt"
    return_code=$(( $return_code & $? ))
    create_link "./$base_domain/key.pem" "/etc/nginx/certs/$domain.key"
    return_code=$(( $return_code & $? ))
    if [[ -f "/etc/nginx/certs/dhparam.pem" ]]; then
        create_link ./dhparam.pem "/etc/nginx/certs/$domain.dhparam.pem"
        return_code=$(( $return_code & $? ))
    fi
    if [[ -f "/etc/nginx/certs/$base_domain/chain.pem" ]]; then
        create_link "./$base_domain/chain.pem" "/etc/nginx/certs/$domain.chain.pem"
        return_code=$(( $return_code & $? ))
    fi
    return $return_code
}

function cleanup_links {
    local -a ENABLED_DOMAINS
    local -a SYMLINKED_DOMAINS
    local -a DISABLED_DOMAINS

    # Create an array containing domains for which a
    # symlinked private key exists in /etc/nginx/certs.
    for symlinked_domain in /etc/nginx/certs/*.crt; do
        [[ -L "$symlinked_domain" ]] || continue
        symlinked_domain="${symlinked_domain##*/}"
        symlinked_domain="${symlinked_domain%*.crt}"
        SYMLINKED_DOMAINS+=("$symlinked_domain")
    done
    log_debug "Symlinked domains: ${SYMLINKED_DOMAINS[*]}"

    # Create an array containing domains that are considered
    # enabled (ie present on /app/letsencrypt_service_data).
    # shellcheck source=/dev/null
    source /app/letsencrypt_service_data
    for cid in "${LETSENCRYPT_CONTAINERS[@]}"; do
      host_varname="LETSENCRYPT_${cid}_HOST"
      hosts_array="${host_varname}[@]"
      for domain in "${!hosts_array}"; do
        # Add domain to the array storing currently enabled domains.
        ENABLED_DOMAINS+=("$domain")
      done
    done
    log_debug "Enabled domains: ${ENABLED_DOMAINS[*]}"

    # Create an array containing only domains for which a symlinked private key exists
    # in /etc/nginx/certs but that no longer have a corresponding LETSENCRYPT_HOST set
    # on an active container.
    if [[ ${#SYMLINKED_DOMAINS[@]} -gt 0 ]]; then
        mapfile -t DISABLED_DOMAINS < <(echo "${SYMLINKED_DOMAINS[@]}" \
                                             "${ENABLED_DOMAINS[@]}" \
                                             "${ENABLED_DOMAINS[@]}" \
                                             | tr ' ' '\n' | sort | uniq -u)
    fi
    log_debug "Disabled domains: ${DISABLED_DOMAINS[*]}"

    # Remove disabled domains symlinks if present.
    # Return 1 if nothing was removed and 0 otherwise.
    if [[ ${#DISABLED_DOMAINS[@]} -gt 0 ]]; then
      log_debug "Some domains are disabled :"
      for disabled_domain in "${DISABLED_DOMAINS[@]}"; do
          log_debug "Checking domain ${disabled_domain}"
          cert_folder="$(readlink -f /etc/nginx/certs/${disabled_domain}.crt)"
          # If the dotfile is absent, skip domain.
          if [[ ! -e "${cert_folder%/*}/.companion" ]]; then
              log_debug "No .companion file found in ${cert_folder}. ${disabled_domain} is not managed by letsencrypt-nginx-proxy-companion. Skipping domain."
              continue
          else
              log_debug "${disabled_domain} is managed by letsencrypt-nginx-proxy-companion. Removing unused symlinks."
          fi

          for extension in .crt .key .dhparam.pem .chain.pem; do
              file="${disabled_domain}${extension}"
              if [[ -n "${file// }" ]] && [[ -L "/etc/nginx/certs/${file}" ]]; then
                  log_debug "Removing /etc/nginx/certs/${file}"
                  rm -f "/etc/nginx/certs/${file}"
              fi
          done
      done
      return 0
    else
      log_debug "There are no domains disabled."
      return 1
    fi
}

function update_certs {

    check_nginx_proxy_container_run || return

    [[ -f /app/letsencrypt_service_data ]] || return

    # Load relevant container settings
    unset LETSENCRYPT_CONTAINERS
    # shellcheck source=/dev/null
    log_debug "Sourcing letsencrypt_service_data"
    test is_debug && cat "$letsencrypt_service_data"
    source /app/letsencrypt_service_data

    should_reload_nginx='false'
    for cid in "${LETSENCRYPT_CONTAINERS[@]}"; do
        should_restart_container='false'
        # Derive host and email variable names
        host_varname="LETSENCRYPT_${cid}_HOST"
        # Array variable indirection hack: http://stackoverflow.com/a/25880676/350221
        hosts_array="${host_varname}[@]"
        hosts_array_expanded=("${!hosts_array}")
        # First domain will be our base domain
        base_domain="${hosts_array_expanded[0]}"

        params_d_str=""

        # Use container's LETSENCRYPT_EMAIL if set, fallback to DEFAULT_EMAIL
        email_varname="LETSENCRYPT_${cid}_EMAIL"
        email_address="${!email_varname}"
        if [[ "$email_address" != "<no value>" ]]; then
            params_d_str+=" --email $email_address"
        elif [[ -n "${DEFAULT_EMAIL:-}" ]]; then
            params_d_str+=" --email $DEFAULT_EMAIL"
        fi

        keysize_varname="LETSENCRYPT_${cid}_KEYSIZE"
        cert_keysize="${!keysize_varname}"
        if [[ "$cert_keysize" == "<no value>" ]]; then
            cert_keysize=$DEFAULT_KEY_SIZE
        fi

        test_certificate_varname="LETSENCRYPT_${cid}_TEST"
        le_staging_uri="https://acme-staging-v02.api.letsencrypt.org/directory"
        if [[ $(lc "${!test_certificate_varname:-}") == true ]] || \
          [[ "$ACME_CA_URI" == "$le_staging_uri" ]]; then
            # Use staging Let's Encrypt ACME end point
            acme_ca_uri="$le_staging_uri"
            # Prefix test certificate directory with _test_
            certificate_dir="/etc/nginx/certs/_test_$base_domain"
        else
            # Use default or user provided ACME end point
            acme_ca_uri="$ACME_CA_URI"
            certificate_dir="/etc/nginx/certs/$base_domain"
        fi

        account_varname="LETSENCRYPT_${cid}_ACCOUNT_ALIAS"
        account_alias="${!account_varname}"
        if [[ "$account_alias" == "<no value>" ]]; then
            account_alias=default
        fi

        [[ "$(lc $DEBUG)" == true ]] && params_d_str+=" -v"
        [[ $REUSE_PRIVATE_KEYS == true ]] && params_d_str+=" --reuse_key"

        min_validity="LETSENCRYPT_${cid}_MIN_VALIDITY"
        min_validity="${!min_validity}"
        if [[ "$min_validity" == "<no value>" ]]; then
            min_validity=$DEFAULT_MIN_VALIDITY
        fi
        # Sanity Check
        # Upper Bound
        if [[ $min_validity -gt $MIN_VALIDITY_CAP ]]; then
            min_validity=$MIN_VALIDITY_CAP
        fi
        # Lower Bound
        if [[ $min_validity -lt $(($seconds_to_wait * 2)) ]]; then
            min_validity=$(($seconds_to_wait * 2))
        fi

        if [[ "${1}" == "--force-renew" ]]; then
            # Manually set to highest certificate lifetime given by LE CA
            params_d_str+=" --valid_min 7776000"
        else
            params_d_str+=" --valid_min $min_validity"
        fi

        # Create directory for the first domain,
        # make it root readable only and make it the cwd
        mkdir -p "$certificate_dir"
        set_ownership_and_permissions "$certificate_dir"
        pushd "$certificate_dir" || return

        for domain in "${!hosts_array}"; do
            # Add all the domains to certificate
            params_d_str+=" -d $domain"
            # Add location configuration for the domain
            add_location_configuration "$domain" || reload_nginx
        done

        if [[ -e "./account_key.json" ]] && [[ ! -e "./account_reg.json" ]]; then
          # If there is an account key present without account registration, this is
          # a leftover from the ACME v1 version of simp_le. Remove this account key.
          rm -f ./account_key.json
          log_debug "removed ACME v1 account key $certificate_dir/account_key.json"
        fi

        # The ACME account key and registration full path are derived from the
        # endpoint URI + the account alias (set to 'default' if no alias is provided)
        account_dir="../accounts/${acme_ca_uri#*://}"
        if [[ $REUSE_ACCOUNT_KEYS == true ]]; then
            for type in "key" "reg"; do
                file_full_path="${account_dir}/${account_alias}_${type}.json"
                simp_le_file="./account_${type}.json"
                if [[ -f "$file_full_path" ]]; then
                    # If there is no symlink to the account file, create it
                    if [[ ! -L "$simp_le_file" ]]; then
                        ln -sf "$file_full_path" "$simp_le_file" \
                          && set_ownership_and_permissions "$simp_le_file"
                    # If the symlink target the wrong account file, replace it
                    elif [[ "$(readlink -f "$simp_le_file")" != "$file_full_path" ]]; then
                        ln -sf "$file_full_path" "$simp_le_file" \
                          && set_ownership_and_permissions "$simp_le_file"
                    fi
                fi
            done
        fi

        log_info "Creating/renewal $base_domain certificates... (${hosts_array_expanded[*]})"
        if development_mode; then
            log_info "Development mode detected. Using self-signed certificates."
            cp -p ../default.crt fullchain.pem
            cp -p ../default.key key.pem
            simp_le_return=0
        else
            /usr/bin/simp_le \
                -f account_key.json -f account_reg.json \
                -f key.pem -f chain.pem -f fullchain.pem -f cert.pem \
                $params_d_str \
                --cert_key_size=$cert_keysize \
                --server=$acme_ca_uri \
                --default_root /usr/share/nginx/html/
            simp_le_return=$?
            log_debug "simp_le_return = $simp_le_return"
        fi

        if [[ $REUSE_ACCOUNT_KEYS == true ]]; then
            mkdir -p "$account_dir"
            for type in "key" "reg"; do
                file_full_path="${account_dir}/${account_alias}_${type}.json"
                simp_le_file="./account_${type}.json"
                # If the account file to be reused does not exist yet, copy it
                # from the CWD and replace the file in CWD with a symlink
                if [[ ! -f "$file_full_path" && -f "$simp_le_file" ]]; then
                    cp "$simp_le_file" "$file_full_path"
                    ln -sf "$file_full_path" "$simp_le_file"
                fi
            done
        fi

        popd || return

        if [[ $simp_le_return -ne 2 ]]; then
          for domain in "${!hosts_array}"; do
            if [[ "$acme_ca_uri" == "$le_staging_uri" ]]; then
              create_links "_test_$base_domain" "$domain" && should_reload_nginx='true' && should_restart_container='true'
            else
              create_links "$base_domain" "$domain" && should_reload_nginx='true' && should_restart_container='true'
            fi
          done
          touch "${certificate_dir}/.companion"
          # Set ownership and permissions of the files inside $certificate_dir
          for file in .companion cert.pem key.pem chain.pem fullchain.pem account_key.json account_reg.json; do
            file_path="${certificate_dir}/${file}"
            [[ -e "$file_path" ]] && set_ownership_and_permissions "$file_path"
          done
          account_path="/etc/nginx/certs/accounts/${acme_ca_uri#*://}"
          account_key_perm_path="${account_path}/${account_alias}_key.json"
          account_reg_perm_path="${account_path}/${account_alias}_reg.json"
          # Account key and registration files do not necessarily exists after
          # simp_le exit code 1. Check if they exist before perm check (#591).
          [[ -f "$account_key_perm_path" ]] && set_ownership_and_permissions "$account_key_perm_path"
          [[ -f "$account_reg_perm_path" ]] && set_ownership_and_permissions "$account_reg_perm_path"
          # Set ownership and permissions of the ACME account folder and its
          # parent folders (up to /etc/nginx/certs/accounts included)
          until [[ "$account_path" == /etc/nginx/certs ]]; do
            set_ownership_and_permissions "$account_path"
            account_path="$(dirname "$account_path")"
          done
          # Queue nginx reload if a certificate was issued or renewed
          [[ $simp_le_return -eq 0 ]] && should_reload_nginx='true' && should_restart_container='true'
        fi

        # Restart container if certs are updated and the respective environmental variable is set
        restart_container_var="LETSENCRYPT_${cid}_RESTART_CONTAINER"
        if [[ $(lc "${!restart_container_var:-}") == true ]] && [[ "$should_restart_container" == 'true' ]]; then
            log_info "Restarting container (${cid})..."
            docker_restart "${cid}"
        fi

    done

    cleanup_links && should_reload_nginx='true' || true
    
    [[ "$should_reload_nginx" == 'true' ]] && reload_nginx
}
