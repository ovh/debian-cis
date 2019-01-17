#!/bin/bash


files=""

if [ $# -eq 0 ]; then
    files=$(find . -name "*.sh")
else
    files="$*"
fi

for f in $files; do
    printf "\e[1;36mRunning shellcheck on: %s  \e[0m\n" "$f"
    /usr/bin/shellcheck --color=always --external-sources --shell=bash "$f"
done
