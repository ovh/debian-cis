#!/bin/bash
set -e

dockerfile="$(dirname "$0")/Dockerfile.shellcheck"
docker build -f "$dockerfile" -t debiancis-shellcheck "$(dirname "$0")"/../
docker run --rm debiancis-shellcheck "$@"

