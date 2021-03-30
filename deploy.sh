#!/bin/bash
declare deployment_file="deployment.yml"
declare deployment_name="reverseproxy"
export MODE=prod
export DEBUG=false
while [[ $# -gt 0 ]]; do
case "$1" in
    --email) export EMAIL="$2"; shift;;
    --mode) MODE="$2"; shift;;
    --debug) DEBUG="true" ;;
    --stack-name) deployment_name="$2"; shift ;;
    -f|--file) deployment_file="$2"; shift ;;
    *) usage; return 1 ;;
esac
shift
done

if [[ ! -f "$deployment_file" ]]; then
    echo "Deployment file '$deployment_file' does not exist..."
    exit 1
fi

declare -r context="$(docker context show)"

echo "Deploying $deployment_name into context $context..."
docker stack deploy -c "$deployment_file" "$deployment_name"