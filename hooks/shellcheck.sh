#!/bin/bash

issues=0

for script in "$@"; do
    /usr/bin/shellcheck --exclude=SC2317 --color=always --shell=bash -x --source-path=SCRIPTDIR "$script"
    [ $? -eq 0 ] || issues=$(($issues + 1))
done

if [ "$issues" -gt 0 ]; then
    exit 1
else
    exit 0
fi
