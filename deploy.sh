#!/bin/bash
set -e

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
    *) 
        echo "$0 OPTIONS"
        echo "--email       Optional. Email to give to CA (LetsEncrypt) to be notify of expiring certificates. Recommended to give valid email. Default none. "
        echo "--mode        Optional. Choices are dev (self-signed), stage (staging ca), prod (trusted certificat). Default prod"
        echo "--debug       Optional. Log level debug. Default false"
        echo "--stack-name  Optional. Docker Stack Name. Default $deployment_name"
        echo "-f|--file     Optional. Deployment file describing the stack. Default $deployment_file"
        exit 1 
    ;;
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