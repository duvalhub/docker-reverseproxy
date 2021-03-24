#!/bin/bash
set -e

source functions.sh

##########################
# Parameters
##########################
usage() {
    echo "$0 [OPTIONS]"
    return 1
}
declare -i waitTime=15
if [ -n "$WAIT_TIME" ]; then
    waitTime="$WAIT_TIME"
fi

while [[ $# -gt 0 ]]; do
    case "$1" in
        --wait) waitTime="$2"; shift; shift;;
        *) usage; exit 1 ;;
    esac
done

while : ; do
    log_info "Launching a new run of processing Docker Services every $waitTime seconds..."
    ./process_docker_services.sh
    log_info "Waiting $waitTime seconds..."
    sleep "$waitTime"
done