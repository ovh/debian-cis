#!/bin/bash
# run-shellcheck
# stop on any error
set -e
# stop on undefined variable
set -u

mytmpdir=$(mktemp -d -t debian-cis-test.XXXXXX)
totalerrors=255

cleanup_and_exit() {
    rm -rf "$mytmpdir"
    if [ "$totalerrors" -eq 255 ]; then
        fatal "RUNTIME ERROR"
    fi
    exit $totalerrors
}
trap "cleanup_and_exit" EXIT HUP INT

outdir="$mytmpdir/out"
mkdir -p "$outdir" || exit 1

tests_list=""
testno=0
testcount=0

skip_tests=0
dismiss_count=0
nbfailedret=0
nbfailedgrep=0
nbfailedconsist=0
listfailedret=""
listfailedgrep=""
listfailedconsist=""

usecase=""
usecase_name=""
usecase_name_root=""
usecase_name_sudo=""
declare -a REGISTERED_TESTS

#####################
# Utility functions #
#####################
# in case a fatal event occurs, fatal logs and exits with return code 1
fatal() {
    printf "\033[1;91m###### \033[0m\n" >&2
    printf "%b %b\n" "\033[1;91mFATAL\033[0m" "$*" >&2
    printf "%b \n" "\033[1;91mEXIT TEST SUITE WITH FAILURE\033[0m" >&2
    trap - EXIT
    exit 255
}
# prints that a test failed
fail() {
    printf "%b %b\n" "\033[1;30m\033[41m[FAIL]\033[0m" "$*" >&2
}
# prints that a test succeded
ok() {
    printf "%b %b\n" "\033[30m\033[42m[ OK ]\033[0m" "$*" >&2
}

skip() {
    printf "%b %b\n" "\033[30m\e[43m[SKIP]\033[0m" "$*" >&2
}
# retrieves audit script logfile
get_stdout() {
    cat "$outdir"/"$usecase_name".log
}

# Reset the list of test assertions
clear_registered_tests() {
    unset REGISTERED_TESTS
    declare -a REGISTERED_TESTS
    # shellcheck disable=2034
    dismiss_count=0
    skip_tests=0
}

# Generates a formated test name
make_usecase_name() {
    usecase=$1
    shift
    role=$1
    usecase_name=$(printf '%03d-%s-%s-%s' "$testno" "$name" "$usecase" "$role" | sed -re "s=/=_=g")
    echo -n "$usecase_name"
}

# Plays the registered test suite
play_registered_tests() {
    if [ "$skip_tests" -eq 1 ]; then
        return
    fi
    usecase_name=$1
    if [[ "${REGISTERED_TESTS[*]}" ]]; then
        export numtest=${#REGISTERED_TESTS[@]}
        for t in "${!REGISTERED_TESTS[@]}"; do
            ${REGISTERED_TESTS[$t]}
        done
    fi
}

# Plays comparison tests to ensure that root and sudo exection have the same output
play_consistency_tests() {
    consist_test=0
    printf "\033[34m*** [%03d] %s::%s Root/Sudo Consistency Tests\033[0m\n" "$testno" "$test_file" "$usecase"
    retfile_root=$outdir/${usecase_name_root}.retval
    retfile_sudo=$outdir/${usecase_name_sudo}.retval
    cmp "$retfile_root" "$retfile_sudo" && ret=0 || ret=1
    if [[ ! 0 -eq $ret ]]; then
        fail "$name" return values differ
        diff "$retfile_root" "$retfile_sudo" || true
        consist_test=1
    else
        ok "$name return values are equal"

    fi
    retfile_root=$outdir/${usecase_name_root}.log
    retfile_sudo=$outdir/${usecase_name_sudo}.log
    cmp "$retfile_root" "$retfile_sudo" && ret=0 || ret=1
    if [[ ! 0 -eq $ret ]]; then
        fail "$name" logs differ
        diff "$retfile_root" "$retfile_sudo" || true
        consist_test=1
    else
        ok "$name logs are identical"
    fi

    if [ 1 -eq $consist_test ]; then
        nbfailedconsist=$((nbfailedconsist + 1))
        listfailedconsist="$listfailedconsist $(make_usecase_name "$usecase" consist)"
    fi
}

# Actually runs one single audit script
_run() {
    usecase_name=$1
    shift
    printf "\033[34m*** [%03d] %s \033[0m(%s)\n" "$testno" "$usecase_name" "$*"
    bash -c "$*" >"$outdir/$usecase_name.log" 2>"$outdir/${usecase_name}_err.log" && true
    echo $? >"$outdir/$usecase_name.retval"
    ret=$(<"$outdir"/"$usecase_name".retval)
    get_stdout
}

# Load assertion functions for functionnal tests
if [ ! -f "$(dirname "$0")"/lib.sh ]; then
    fatal "Cannot locate lib.sh"
fi
# shellcheck source=../tests/lib.sh
. "$(dirname "$0")"/lib.sh

###################
# Execution start #
###################
printf "\033[1;36m###\n### %s\n### \033[0m\n" "Starting debian-cis functional testing"

# if no scripts were passed as arguments, list all available test scenarii to be played
if [ $# -eq 0 ]; then
    tests_list=$(ls -v "$(dirname "$0")"/hardening/)
    testcount=$(wc -l <<<"$tests_list")
else
    tests_list="$*"
    testcount=$#
fi

for test_file in $tests_list; do
    test_file_path=$(dirname "$0")/hardening/"$test_file"
    if [ ! -f "$test_file_path" ]; then
        fatal "Test file \"$test_file\" does not exist"
    fi
    # script var is used inside test files
    # shellcheck disable=2034
    script="$(basename "$test_file" .sh)"
    # source test scenario file to add `test_audit` func
    # shellcheck disable=1090
    . "$test_file_path"
    testno=$((testno + 1))
    # shellcheck disable=2001
    name="$(echo "${test_file%%.sh}" | sed 's/\d+\.\d+_//')"
    printf "\033[1;36m### [%03d/%03d] %s \033[0m\n" "$testno" "$testcount" "$test_file"
    # test_audit is the function defined in $test_file, that carries the actual functional tests for this script
    test_audit
    # reset var names
    usecase_name=""
    usecase_name_root=""
    usecase_name_sudo=""
    unset -f test_audit
    echo ""
done

stderrunexpected=""
for file in "$outdir"/*_err.log; do
    if [ -s "$file" ]; then
        stderrunexpected="$stderrunexpected $(basename "$file")"
    fi
done

printf "\033[1;36m###\n### %s \033[0m\n" "Test report"
if [ $((nbfailedret + nbfailedgrep + nbfailedconsist)) -eq 0 ] && [ -z "$stderrunexpected" ]; then
    echo -e "\033[42m\033[30mAll tests succeeded :)\033[0m"
    echo -e "\033[42m\033[30mStderr is empty :)\033[0m"

else
    (
        echo -e "\033[41mOne or more tests failed :(\033[0m"
        echo -e "- $nbfailedret unexpected return values ${listfailedret}"
        echo -e "- $nbfailedgrep unexpected text values $listfailedgrep"
        echo -e "- $nbfailedconsist root/sudo consistency $listfailedconsist"
        echo -e "- stderr detected on $stderrunexpected"
    ) | tee "$outdir"/summary
fi
echo

set +e
set +u
totalerrors=$((nbfailedret + nbfailedgrep + nbfailedconsist))
# leave `exit 255` for runtime errors
[ $totalerrors -ge 255 ] && totalerrors=254
exit $totalerrors
