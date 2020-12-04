# shellcheck shell=bash
# run-shellcheck
test_audit() {
    describe Running on blank host
    register_test retvalshouldbe 0
    dismiss_count_for_test
    # shellcheck disable=2154
    run blank /opt/debian-cis/bin/hardening/"${script}".sh --audit-all

    local test_user="testpasswdgroupuser"
    local dir="/etc/passwd"

    describe Tests purposely failing
    echo "$test_user:x:1100:1100::/home/$test_user:" >>"$dir"
    register_test retvalshouldbe 1
    register_test contain "is referenced by /etc/passwd but does not exist in /etc/group"
    run noncompliant /opt/debian-cis/bin/hardening/"${script}".sh --audit-all

    # cleanup
    userdel "$test_user"
}
