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


source functions.sh

while : ; do
    printf "\n\n##### New Run \n"
    date
    ./process_docker_services.sh
    waitTime=15
    log_info "Waiting $waitTime seconds..."
    sleep "$waitTime"
done