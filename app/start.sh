#!/bin/bash

source functions.sh

##########################
# utils
##########################
epoch_seconds() {
    date +%s
}

##########################
# Parameters
##########################
usage() {
    echo "$0 [OPTIONS]"
    return 1
}
declare -i last_triggered=$(epoch_seconds)
declare -i minimum_elasped=${MINIMUM_TIME:-60}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --wait) minimum_elasped="$2"; shift; shift;;
        *) usage; exit 1 ;;
    esac
done

##########################
# Clean exit
##########################
# SIGTERM-handler
term_handler() {
    log_info "[start.sh] Received termination signal. Propagating to child..."
    [[ -n "$docker_service_pid" ]] && kill $docker_service_pid

    source functions.sh
    remove_all_location_configurations

    exit 0
}

trap 'term_handler' INT QUIT TERM

##########################
# Begin
##########################
log_debug "Starting Docker Service Watcher..."

./docker_service.sh &
docker_service_pid=$!

log_debug "docker_service running on id '$docker_service_pid'"

handle_events() {
    declare -r now=$(epoch_seconds)
    declare time_elapsed=$(($now-$last_triggered))
    log_info "Event detected. Evaluating elapse time since last reload..."
    log_debug "Event: $event"
    if [[ "$time_elapsed" -gt "$minimum_elasped" ]]; then
        log_info "Enough time has passed. Elapsed $time_elapsed > Threshold $minimum_elasped. Triggering a new run"
        log_debug "Events detected. Killing docker_service'$docker_service_pid'..."
        log_debug "Event: $event"
        kill -1 "$docker_service_pid"
        last_triggered=$(epoch_seconds)
    else
        log_info "Not enough time has passed since last trigger. Elapsed $time_elapsed < Threshold $minimum_elasped"
    fi
}

docker events --filter type=service | while read event
do
    handle_events "$event"
done &

wait
