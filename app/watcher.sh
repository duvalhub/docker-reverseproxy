#!/bin/bash -e
source functions.sh

while : ; do
    printf "\n\n##### New Run \n"
    date
    ./process_docker_services.sh
    waitTime=15
    log_info "Waiting $waitTime seconds..."
    sleep "$waitTime"
done