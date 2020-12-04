#! /bin/bash
# This file builds a docker image for testing the targeted debian version
# run-shellcheck
set -e

target=""
regex="debian[[:digit:]]+"

if [ $# -gt 0 ]; then
    if [[ $1 =~ $regex ]]; then
        target=$1
        shift
    fi
fi
if [ -z "$target" ]; then
    echo "Usage: $0 <TARGET> [test_script...]" >&2
    echo -n "Supported targets are: " >&2
    #ls -1v  "$(dirname "$0")"/docker/Dockerfile.* | sed -re 's=^.+/Dockerfile\.==' | tr "\n" " " >&2
    find "$(dirname "$0")"/docker -name "*Dockerfile.*" | sort -V | sed -re 's=^.+/Dockerfile\.==' | tr "\n" " " >&2
    echo >&2
    exit 1
fi

dockerfile="$(dirname "$0")"/docker/Dockerfile.${target}
if [ ! -f "$dockerfile" ]; then
    echo "ERROR: No target available for $target" >&2
    exit 1
fi

docker build -f "$dockerfile" -t "debian_cis_test:${target}" "$(dirname "$0")"/../

docker run --rm debian_cis_test:"${target}" "$@"
