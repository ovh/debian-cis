# shellcheck shell=bash
# run-shellcheck
test_audit() {
    describe Running on blank host
    register_test retvalshouldbe 0
    dismiss_count_for_test
    # shellcheck disable=2154
    run blank "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    local test_user="testforwarduser"
    local test_file=".forward"

    describe Tests purposely failing
    useradd --create-home "$test_user"
    chmod o+rx "/home/$test_user/"
    touch "/home/$test_user/$test_file"
    register_test retvalshouldbe 1
    register_test contain "$test_file present"
    run noncompliant "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    # cleanup
    userdel -r "$test_user"
}
