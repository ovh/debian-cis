#!/bin/bash
# run-shellcheck
# please do not run this script directly but `docker_build_and_run_shellcheck.sh`

files=""
retval=0

if [ "$#" -eq 0 ]; then
    files=$(find . -name "*.sh" | sort -V)
else
    files="$*"
fi

for f in $files; do
    if head "$f" | grep -qE "^# run-shellcheck$"; then
        printf "\e[1;36mRunning shellcheck on: %s  \e[0m\n" "$f"
        # SC2317: command unreachable, sometimes has a hard time reaching the command in a function
        if ! /usr/bin/shellcheck --exclude=SC2317 --color=always --shell=bash -x --source-path=SCRIPTDIR "$f"; then
            retval=$((retval + 1))
        fi
    fi
done
exit "$retval"
