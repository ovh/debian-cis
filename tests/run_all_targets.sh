#!/bin/bash
# run-shellcheck
# usage : $0 [--nodel|--nowait] [1.1_script-to-test.sh...]
# --nodel will keep logs
# --nowait will not wait for you to see logs
# if all test docker passed return 0, otherwise 1 meaning some tests failed

tmpdir=$(mktemp -d -t debcistest.XXXXXX)
failedtarget=""

cleanup() {
    if [ "$nodel" -eq 0 ]; then
        rm -rf "$tmpdir"
    fi
}

# `exit 255` for runtime error
trap "cleanup; exit 255" EXIT HUP INT

if [ ! -t 0 ]; then
    echo -e "\e[34mNo stdin \e[0m"
    nodel=1
    nowait=1
fi

nodel=0
nowait=0
OPTIONS=$(getopt --long nodel,nowait -- "$0" "$@")
eval set -- "$OPTIONS"
# Treating options
while true; do
    case "$1" in
    --nodel)
        nodel=1
        shift
        ;;
    --nowait)
        nowait=1
        shift
        ;;
    --)
        shift
        break
        ;;
    *) break ;;
    esac
done

# Execution summary
if [ "$nodel" -eq 1 ]; then
    echo -e "\e[34mLog directory: $tmpdir \e[0m"
fi
if [ "$nowait" -eq 1 ]; then
    echo -e "\e[34mRunning in non-interactive mode\e[0m"
fi

# Actual execution
# Loops over found targets and runs docker_build_and_run_tests
for target in $("$(dirname "$0")"/docker_build_and_run_tests.sh 2>&1 | grep "Supported" | cut -d ':' -f 2); do
    echo "Running $target $*"
    "$(dirname "$0")"/docker_build_and_run_tests.sh "$target" "$@" 2>&1 |
        tee "${tmpdir}"/"${target}" |
        grep -q "All tests succeeded"
    ret=$?
    if [[ 0 -eq $ret ]]; then
        echo -e "\e[92mOK\e[0m $target"
    else
        echo -e "\e[91mKO\e[0m $target"
        failedtarget="$failedtarget ${tmpdir}/${target}"
    fi
done

if [[ -n "$failedtarget" && "$nowait" -eq 0 ]]; then
    echo -e "\nPress \e[1mENTER\e[0m to display failed test logs"
    echo -e "Use \e[1m:n\e[0m (next) and \e[1m:p\e[0m (previous) to navigate between log files"
    echo -e "and \e[1mq\e[0m to quit"
    # shellcheck disable=2015,2162,2034
    test -t 0 && read _wait || true
    # disable shellcheck to allow expansion of logfiles list
    # shellcheck disable=2086
    less -R $failedtarget
fi

trap - EXIT HUP INT
cleanup

exit ${failedtarget:+1}
