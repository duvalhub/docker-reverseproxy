#!/bin/bash
set -e

#######################
# Functions
#######################
deploy-file-is-remote() {
    [[ "$deployment_file" = "https://"* ]]
}

#######################
# Arguments
#######################
declare deployment_file="deployment.yml"
declare deployment_name="reverseproxy"
export MODE=prod
export DEBUG=false
export NGINX_COMPANION_VERSION=latest
while [[ $# -gt 0 ]]; do
case "$1" in
    --env) env="$2"; shift;;
    --email) export EMAIL="$2"; shift;;
    --mode) MODE="$2"; shift;;
    --debug) DEBUG="true" ;;
    --version) NGINX_COMPANION_VERSION="$2"; shift ;;
    --stack-name) deployment_name="$2"; shift ;;
    -f|--file) deployment_file="$2"; shift ;;
    *) 
        echo "$0 OPTIONS"
        echo "--env         Required. The Context in which deploy reverseproxy"
        echo "--email       Optional. Email to give to CA (LetsEncrypt) to be notify of expiring certificates. Recommended to give valid email. Default none. "
        echo "--mode        Optional. Choices are dev (self-signed), stage (staging ca), prod (trusted certificat). Default prod"
        echo "--debug       Optional. Log level debug. Default false"
        echo "--version     Optional. Nginx Companion Version. Default latest"
        echo "--stack-name  Optional. Docker Stack Name. Default $deployment_name"
        echo "-f|--file     Optional. Deployment file describing the stack. Default $deployment_file"
        exit 1 
    ;;
esac; shift; done
[ -z "$env" ] && echo "Missing --env param" && exit 1
[ ! -f "$deployment_file" ] && deployment_file="https://raw.githubusercontent.com/duvalhub/docker-reverseproxy/main/deployment.yml"

if deploy-file-is-remote; then
    echo "Downloading deployment file from '$deployment_file'..."
    deployment_file_tmp=$(mktemp)
    curl -o "$deployment_file_tmp" "$deployment_file"
    deployment_file="$(mktemp)"
    mv "$deployment_file_tmp" "$deployment_file"
fi
if [[ ! -f "$deployment_file" ]]; then
    echo "Deployment file '$deployment_file' does not exist..."
    exit 1
fi

echo "Deploying $deployment_name into context $env..."
docker --context "$env" stack deploy -c "$deployment_file" "$deployment_name"

deploy-file-is-remote && rm -f "$deployment_file" 