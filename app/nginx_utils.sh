#!/bin/bash

generate_basic_nginx_conf() {
    cat <<-'EOF'
# If we receive X-Forwarded-Proto, pass it through; otherwise, pass along the
# scheme used to connect to this server
map $http_x_forwarded_proto $proxy_x_forwarded_proto {
  default $http_x_forwarded_proto;
  ''      $scheme;
}
# If we receive X-Forwarded-Port, pass it through; otherwise, pass along the
# server port the client connected to
map $http_x_forwarded_port $proxy_x_forwarded_port {
  default $http_x_forwarded_port;
  ''      $server_port;
}
# If we receive Upgrade, set Connection to "upgrade"; otherwise, delete any
# Connection header that may have been passed to this server
map $http_upgrade $proxy_connection {
  default upgrade;
  '' close;
}
# Apply fix for very long server names
server_names_hash_bucket_size 128;
# Default dhparam
# Set appropriate X-Forwarded-Ssl header
map $scheme $proxy_x_forwarded_ssl {
  default off;
  https on;
}
gzip_types text/plain text/css application/javascript application/json application/x-javascript text/xml application/xml application/xml+rss text/javascript;
log_format vhost '$host $remote_addr - $remote_user [$time_local] '
                 '"$request" $status $body_bytes_sent '
                 '"$http_referer" "$http_user_agent"';
access_log off;
ssl_protocols TLSv1.2 TLSv1.3;
ssl_ciphers 'ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:DHE-RSA-AES128-GCM-SHA256:DHE-RSA-AES256-GCM-SHA384';
ssl_prefer_server_ciphers off;
# HTTP 1.1 support
proxy_http_version 1.1;
proxy_buffering off;
proxy_set_header Host $http_host;
proxy_set_header Upgrade $http_upgrade;
proxy_set_header Connection $proxy_connection;
proxy_set_header X-Real-IP $remote_addr;
proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
proxy_set_header X-Forwarded-Proto $proxy_x_forwarded_proto;
proxy_set_header X-Forwarded-Ssl $proxy_x_forwarded_ssl;
proxy_set_header X-Forwarded-Port $proxy_x_forwarded_port;
# Mitigate httpoxy attack (see README for details)
proxy_set_header Proxy "";
EOF
}

generate_basic_http_conf() {
    cat <<-'EOF'
server {
    server_name _; # This is just an invalid value which will never trigger on a real hostname.
    listen 80;
    access_log /var/log/nginx/access.log vhost;
    return 503;
}

EOF
}

generate_basic_https_conf() {
    cat <<-'EOF'
server {
    server_name _; # This is just an invalid value which will never trigger on a real hostname.
    listen 443 ssl http2;
    access_log /var/log/nginx/access.log vhost;
    return 503;
    ssl_session_cache shared:SSL:50m;
    ssl_session_tickets off;
    ssl_certificate /etc/nginx/certs/default.crt;
    ssl_certificate_key /etc/nginx/certs/default.key;
}

EOF
}

generate_basic_conf() {
    generate_basic_nginx_conf
    cat <<-'EOF'

##############################
# Generic Server Configurations
##############################
EOF
    generate_basic_http_conf
     if [ -f "$NGINX_HOME/certs/default.crt" ] && [ -f "$NGINX_HOME/certs/default.key" ]; then
        generate_basic_https_conf
    fi
}

nginx_write_http_block() {
    local -a params=("$@")
    local -r name="${params[0]?Missing NAME as second param}"
    local -r dns="${params[1]?Missing DNS as second param}"
    local -r base_domain="$(echo "$dns" | cut -d' ' -f1)"
    local -i port="${params[2]:-80}"
    cat <<-EOF
# BEGIN $name
# upstream $base_domain {
#     server $name:$port;
# }
server {
    server_name $dns;
    listen 80 ;
    resolver 127.0.0.11 valid=30s;
    include /etc/nginx/vhost.d/default;
    location / {
        set $upstream $name:$port;
        proxy_pass http://$upstream;
        proxy_pass http://$base_domain;
    }
}
# END $name
EOF
}

nginx_write_https_block() {
    local -a params=("$@")
    local -r name="${params[0]?Missing NAME as second param}"
    local -r dns="${params[1]?Missing DNS as second param}"
    local -r base_domain="$(echo "$dns" | cut -d' ' -f1)"
    local -i port="${params[2]:-80}"
    cat <<-EOF
# BEGIN $name
# upstream $base_domain {
#     server $name:$port;
# }
server {
    server_name $dns;
    listen 80 ;
    access_log /var/log/nginx/access.log vhost;
    include /etc/nginx/vhost.d/default;
    location / {
        return 301 https://\$host\$request_uri;
    }
}
server {
    server_name $dns;
    listen 443 ssl http2 ;
    resolver 127.0.0.11 valid=30s;
    access_log /var/log/nginx/access.log vhost;
    ssl_session_timeout 5m;
    ssl_session_cache shared:SSL:50m;
    ssl_session_tickets off;
    ssl_certificate /etc/nginx/certs/$base_domain.crt;
    ssl_certificate_key /etc/nginx/certs/$base_domain.key;
    location / {
        set $upstream $name:$port;
        proxy_pass http://$upstream;
        # proxy_pass http://$base_domain;
    }
}
# END $name
EOF
}

nginx_write_block() {
    local -a params=("$@")
    local -r destination="${params[-1]}"
    local -r name="${params[0]?Missing NAME as second param}"
    local -r dns="${params[1]?Missing DNS as second param}"
    local -r base_domain="$(echo "$dns" | cut -d' ' -f1)"
    local -r port="${params[2]:-80}"
    unset params[-1]
    local ssl=false
    if [ -f "$NGINX_HOME/certs/$base_domain.crt" ] && [ -f "$NGINX_HOME/certs/$base_domain.key" ]; then
        ssl=true
    else
        log_debug "[SERVICE][$name] Ssl not detected for service $name. "
    fi
    local generator_fct
    if [ "$ssl" = true ]; then
        log_debug "[SERVICE][$name][HTTPS] Registering $name:$port ($dns) with ssl"
        generator_fct=nginx_write_https_block
    else
        log_debug "[SERVICE][$name][HTTP] Registering $name:$port ($dns) without ssl."
        generator_fct=nginx_write_http_block
    fi
    
    "$generator_fct" "${params[@]}" >> "$destination"
}

register_service() {
    usage() {
        echo "register_service [OPTIONS]"
        return 1
    }
    while [[ $# -gt 0 ]]; do
    local key="$1"
    case $key in
        --name) local name="$2"; shift; shift;;
        --dns) local dns="$2"; shift; shift;;
        --port) local port="${2:-80}"; shift; shift;;
        --destination) local destination="$2"; shift; shift;;
        *) usage; return 1 ;;
    esac
    done

    if [ -z "$name" ] || [ -z "$dns" ] || [ -z "$destination" ]; then
        echo "Missing required arguments"
        usage
        return 1
    fi
    log_debug "[SERVICE][$name] Processing service '$name:$port' ($dns)..."
    nginx_write_block "$name" "$dns" "$port" "$destination"
}

generate_nginx_conf() {
    local services="$1"
    local nginx_conf="$2"
    cat > "$nginx_conf" <<-'EOF' 

##############################
# Generic Configurations
##############################
EOF

    generate_basic_conf >> "$nginx_conf"

    cat >> "$nginx_conf" <<-'EOF'

##############################
# Application Configurations
##############################
EOF

    cat "$services" | jq -r '. | [.name,.host,.port] | @tsv' |
    while IFS=$'\t' read -r name host port; do
        register_service --name "$name" --dns "$host" --port "$port" --destination "$nginx_conf"
    done 
}
