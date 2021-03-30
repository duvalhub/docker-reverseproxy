#!/bin/bash
set -e

declare -r version="${1:-latest}"
declare -r image="duvalhub/nginx-companion:latest"

if [[ "$version" != "latest" && ! -z "$(git status --porcelain)" ]]; then 
  echo "Working directory not clean. Commit before release"
  exit 1
fi

docker build -t "$image" .
docker push "$image"

if [[ "$version" != "latest" ]]; then
    git tag "$version"
    git push --tags
fi