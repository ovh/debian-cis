# shellcheck shell=bash
# run-shellcheck
###########################################
# Assertion functions for funcional tests #
###########################################

# sugar to add a decription of the test suite
# describe <STRING>
describe() {
    # shellcheck disable=2154
    printf "\033[4;36mxxx %s::%s \033[0m\n" "$name" "$*"
}

# Register an assertion on an audit before running it
# May be used several times
# See below assertion functions
# register_test <TEST_STRING>
register_test() {
    export numtest=0
    if [[ "notempty" == "${REGISTERED_TESTS[*]:+notempty}" ]]; then
        numtest=${#REGISTERED_TESTS[@]}
    fi
    REGISTERED_TESTS[numtest]="$*"
}

# retvalshouldbe checks that the audit return value equals the one passed as parameter
# retvalshoudbe <NUMBER>
retvalshouldbe() {
    # shellcheck disable=2154
    retfile=$outdir/${usecase_name}.retval
    shouldbe=$1
    got=$(<"$retfile")
    if [ "$got" = "$shouldbe" ]; then
        ok "RETURN VALUE" "($shouldbe)"
    else
        if [ 0 -eq "$dismiss_count" ]; then
            nbfailedret=$((nbfailedret + 1))
            listfailedret="$listfailedret $usecase_name"
        fi
        fail "RETURN VALUE" "(got $got instead of $shouldbe)"
    fi
}

# contain looks for a string in audit logfile
# contain [REGEX] <STRING|regexSTRING>
contain() {
    local specialoption=''
    if [ "$1" != "REGEX" ]; then
        specialoption='-F'
    else
        specialoption='-E'
        shift
    fi
    file=$outdir/${usecase_name}.log
    pattern=$*
    if grep -q $specialoption -- "$pattern" "$file"; then
        ok "MUST CONTAIN" "($pattern)"
    else
        if [ 0 -eq "$dismiss_count" ]; then
            nbfailedgrep=$((nbfailedgrep + 1))
            listfailedgrep="$listfailedgrep $usecase_name"
        fi
        fail "MUST CONTAIN" "($pattern)"
    fi
}

# Do not run tests at all for the next `run`
skip_tests() {
    # shellcheck disable=2034
    skip_tests=1
}

# test is expected to fail (for instance on blank system)
# then the test wont be taken into account for test suite success
dismiss_count_for_test() {
    dismiss_count=1
}

# Run the audit script in both root and sudo mode and plays assertion tests and
# sudo/root consistency tests
# run <USECASE> <AUDIT_SCRIPT>
run() {
    usecase=$1
    shift
    usecase_name_root=$(make_usecase_name "$usecase" "root")
    _run "$usecase_name_root" "$@"
    play_registered_tests "$usecase_name_root"

    usecase_name_sudo=$(make_usecase_name "$usecase" "sudo")
    _run "$usecase_name_sudo" "sudo -u secaudit" "$@" "--sudo"
    play_registered_tests "$usecase_name_sudo"

    play_consistency_tests
    clear_registered_tests
}
