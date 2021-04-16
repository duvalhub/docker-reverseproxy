#!/bin/bash
set -e

declare -r version="${1:-latest}"
declare -r image="duvalhub/nginx-companion:$version"

while [[ $# -gt 0 ]]; do
case "$1" in
    -h|--help)
        echo "$0 [version]"
        echo "version       Optional. Version to build and release. Default to latest"
        exit
    ;;
esac
shift
done

if [[ "$version" != "latest" && ! -z "$(git status --porcelain)" ]]; then 
  echo "Working directory not clean. Commit before release"
  exit 1
fi

echo "Building and Releasing $image..."
docker build -t "$image" .
docker push "$image"

if [[ "$version" != "latest" ]]; then
    git tag "$version"
    git push --tags
fi