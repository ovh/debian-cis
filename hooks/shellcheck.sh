#!/bin/bash

for script in "$@"; do
    /usr/bin/shellcheck --exclude=SC2317 --color=always --shell=bash -x --source-path=SCRIPTDIR "$script"
done

exit 0
