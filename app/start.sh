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

log_debug "Starting process_docker_services..."


./process_docker_services.sh &
process_docker_services_pid=$!

log_debug "process_docker_services running on id '$process_docker_services_pid'"

docker events --filter type=service | while read event
do
    log_info "Events detected. Killing process_docker_services '$process_docker_services_pid'..."
    log_debug "Event: $event"
    kill -1 "$process_docker_services_pid"
done


# wait "indefinitely"
# while [[ -e /proc/$docker_gen_pid ]]; do
#     wait $docker_gen_pid # Wait for any signals or end of execution of docker-gen
# done


# while : ; do
#     log_info "Launching a new run of processing Docker Services every $waitTime seconds..."
#     ./process_docker_services.sh
#     log_info "Waiting $waitTime seconds..."
#     sleep "$waitTime"
# done
