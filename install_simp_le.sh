#!/bin/bash -e

# Install python and packages needed to build simp_le
build_dependencies="git gcc musl-dev libffi-dev python3-dev openssl-dev"
apk add --update python3 py3-pip $build_dependencies

# Create expected symlinks if they don't exist
[[ -e /usr/bin/python ]] || ln -sf /usr/bin/python3 /usr/bin/python

# Get Let's Encrypt simp_le client source
branch="0.16.0"
mkdir -p /src
git -C /src clone --depth=1 --branch $branch https://github.com/zenhack/simp_le.git

# Install simp_le in /usr/bin
cd /src/simp_le
#pip install wheel requests
for pkg in pip setuptools wheel
do
  pip install -U "${pkg?}"
done
CRYPTOGRAPHY_DONT_BUILD_RUST=1 pip install .

# Make house cleaning
cd /
rm -rf /src
apk del $build_dependencies
rm -rf /var/cache/apk/*
