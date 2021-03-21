#!/bin/bash -e

function check_docker_socket {
    if [[ $DOCKER_HOST == unix://* ]]; then
        socket_file=${DOCKER_HOST#unix://}
        if [[ ! -S $socket_file ]]; then
            echo "Error: you need to share your Docker host socket with a volume at $socket_file" >&2
            echo "Typically you should run your container with: '-v /var/run/docker.sock:$socket_file:ro'" >&2
            exit 1
        fi
    fi
}

function check_writable_directory {
    local dir="$1"
    if [[ $(get_self_cid) ]]; then
        docker_api "/containers/$(get_self_cid)/json" | jq ".Mounts[].Destination" | grep -q "^\"$dir\"$"
        [[ $? -ne 0 ]] && echo "Warning: '$dir' does not appear to be a mounted volume."
    else
        echo "Warning: can't check if '$dir' is a mounted volume without self container ID."
    fi
    if [[ ! -d "$dir" ]]; then
        echo "Error: can't access to '$dir' directory !" >&2
        echo "Check that '$dir' directory is declared as a writable volume." >&2
        exit 1
    fi
    touch $dir/.check_writable 2>/dev/null
    if [[ $? -ne 0 ]]; then
        echo "Error: can't write to the '$dir' directory !" >&2
        echo "Check that '$dir' directory is export as a writable volume." >&2
        exit 1
    fi
    rm -f $dir/.check_writable
}

source functions.sh

if [[ "$*" == "/bin/bash watcher.sh" ]]; then
    check_docker_socket
    check_writable_directory "$NGINX_HOME/conf.d"
    check_writable_directory "$NGINX_HOME/certs"
    # check_writable_directory '/usr/share/nginx/html'
fi

exec "$@"