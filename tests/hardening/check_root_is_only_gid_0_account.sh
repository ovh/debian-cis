# shellcheck shell=bash
# run-shellcheck
test_audit() {
    describe Running on blank host
    register_test retvalshouldbe 0
    dismiss_count_for_test
    # shellcheck disable=2154
    run blank "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    describe Tests purposely failing - creating GID 0 user
    useradd -o -g 0 testgid0user || true
    register_test retvalshouldbe 1
    register_test contain "have GID 0"
    run noncompliant "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    describe Manual fix
    userdel testgid0user || true

    describe Checking resolved state
    register_test retvalshouldbe 0
    register_test contain "Only root account has GID 0"
    run resolved "${CIS_CHECKS_DIR}/${script}.sh" --audit-all
}
