# shellcheck shell=bash
# run-shellcheck
test_audit() {
    describe Running on blank host
    register_test retvalshouldbe 0
    # shellcheck disable=2154
    run blank /opt/debian-cis/bin/hardening/"${script}".sh --audit-all

    local test_user="userwithouthome"
    useradd "$test_user"
    describe Tests purposely failing
    register_test retvalshouldbe 1
    register_test contain "does not exist."
    run noncompliant /opt/debian-cis/bin/hardening/"${script}".sh --audit-all

    # cleanup
    userdel "$test_user"
}
