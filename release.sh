#!/bin/bash
set -e

declare -r image="duvalhub/nginx-companion:latest"

docker build -t "$image" .

docker push "$image"