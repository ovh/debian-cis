# shellcheck shell=bash
# run-shellcheck
test_audit() {
    describe prepare failing test
    local test_user="wrong_group_user"
    useradd -M "$test_user"
    sed -i "/^$test_user:/d" /etc/group

    describe Tests purposely failing
    register_test retvalshouldbe 1
    # shellcheck disable=2154
    run noncompliant "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    describe fixing situation
    userdel -r "$test_user"

    describe Checking resolved state
    register_test retvalshouldbe 0
    run resolved "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

}
