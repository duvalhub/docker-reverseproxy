#!/bin/bash
set -e

source functions.sh

while : ; do
    log_info "Launching a new run of processing Docker Services..."
    ./process_docker_services.sh
    declare -i waitTime=15
    log_info "Waiting $waitTime seconds..."
    sleep "$waitTime"
done