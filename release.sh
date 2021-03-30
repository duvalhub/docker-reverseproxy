#!/bin/bash

declare -r image="duvalhub/nginx-companion"

docker build -t "$image" .

docker push "$image"