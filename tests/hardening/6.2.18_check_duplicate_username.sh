# shellcheck shell=bash
# run-shellcheck
test_audit() {
    describe Running on blank host
    register_test retvalshouldbe 0
    dismiss_count_for_test
    # shellcheck disable=2154
    run blank "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    local test_user="testduplicateuser"
    local dir="/etc/passwd"

    describe Tests purposely failing
    useradd "$test_user"
    temp=$(tail -1 "$dir")
    echo "$temp" >>"$dir"
    register_test retvalshouldbe 1
    register_test contain "Duplicate username"
    run noncompliant "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    # cleanup
    sed -i '$ d' "$dir"
    userdel "$test_user"
}
