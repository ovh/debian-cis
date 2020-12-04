#!/bin/bash
# run-shellcheck
# usage : $0 [shell script to check]
# called without arguments, il will shellcheck any *.sh file found in the project
set -e

dockerfile="$(dirname "$0")/Dockerfile.shellcheck"
docker build -f "$dockerfile" -t debiancis-shellcheck "$(dirname "$0")"/../
docker run --rm debiancis-shellcheck "$@"
