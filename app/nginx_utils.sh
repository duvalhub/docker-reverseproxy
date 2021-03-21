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
    listen 80;
    access_log /var/log/nginx/access.log vhost;
    return 503;
}
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
     if [ -f "$SSL_CERTIFICATES/default.crt" ] && [ -f "$SSL_CERTIFICATES/default.key" ]; then
        ssl=true
    fi
    local generator_fct
    if [ "$ssl" = true ]; then
        generator_fct=generate_basic_https_conf
    else
        generator_fct=generate_basic_http_conf
    fi
    cat <<-'EOF'

##############################
# Generic Server Configurations
##############################
EOF
    "$generator_fct"
}

nginx_write_http_block() {
    local name="$1"
    local dns="$2"
    cat <<-EOF
# BEGIN $name
upstream $dns {
    server $name:80;
}
server {
    server_name $dns;
    listen 80 ;
    location / {
        proxy_pass http://$dns;
    }
}
# END $name
EOF
}

nginx_write_https_block() {
    local name="$1"
    local dns="$2"
    cat <<-EOF
# BEGIN $name
upstream $dns {
    server $name:80;
}
server {
    server_name $dns;
    listen 80 ;
    access_log /var/log/nginx/access.log vhost;
    return 307 https://\$host\$request_uri;
}
server {
    server_name $dns;
    listen 443 ssl http2 ;
    access_log /var/log/nginx/access.log vhost;
    ssl_session_timeout 5m;
    ssl_session_cache shared:SSL:50m;
    ssl_session_tickets off;
    ssl_certificate /etc/nginx/certs/$dns.crt;
    ssl_certificate_key /etc/nginx/certs/$dns.key;
    # include /etc/nginx/vhost.d/default;
    location / {
        proxy_pass http://$dns;
    }
}
# END $name
EOF
}

nginx_write_block() {
    local name="$1"
    local dns="$2"
    local ssl=false
    if [ -f "$SSL_CERTIFICATES/$dns.crt" ] && [ -f "$SSL_CERTIFICATES/$dns.key" ]; then
        ssl=true
    fi
    local generator_fct
    if [ "$ssl" = true ]; then
        generator_fct=nginx_write_https_block
    else
        generator_fct=nginx_write_http_block
    fi

    "$generator_fct" "$name" "$dns" 
}
unregister_service() {
    usage() {
        echo "register_service [OPTIONS]"
        return 1
    }
    while [[ $# -gt 0 ]]; do
    local key="$1"
    case $key in
        --name) local name="$2"; shift; shift;;
        --dns) local dns="$2"; shift; shift;;
        --destination) local destination="$2"; shift; shift;;
        *) usage; return 1 ;;
    esac
    done

    if [ -z "$name" ] || [ -z "$dns" ] || [ -z "$destination" ]; then
        echo "Missing required arguments"
        usage
        return 1
    fi
    sed -i "/^# BEGIN $name/,/^# END $name/d" "$destination"
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
        --destination) local destination="$2"; shift; shift;;
        *) usage; return 1 ;;
    esac
    done

    if [ -z "$name" ] || [ -z "$dns" ] || [ -z "$destination" ]; then
        echo "Missing required arguments"
        usage
        return 1
    fi
    nginx_write_block "$name" "$dns" >> "$destination"
}

generate_nginx_conf() {
    local services="$1"
    local nginx_conf="$2"
    cat >> "$nginx_conf" <<-'EOF' 

##############################
# Generic Configurations
##############################
EOF

    generate_basic_conf >> "$nginx_conf"

    cat <<-'EOF' >> "$nginx_conf"

##############################
# Application Configurations
##############################
EOF

    cat "$services" | jq -r '. | [.name,.host] | @tsv' |
    while IFS=$'\t' read -r name host; do
        register_service --name "$name" --dns "$host" --destination "$nginx_conf"
    done
    # echo "Processing $services"
    # cat "$services"
}
