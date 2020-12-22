# shellcheck shell=bash
# run-shellcheck
test_audit() {
    describe Running on blank host
    register_test retvalshouldbe 0
    dismiss_count_for_test
    # shellcheck disable=2154
    run blank /opt/debian-cis/bin/hardening/"${script}".sh --audit-all

    local dir="/test"
    local test_user="userrootpathtest"

    describe Tests purposely failing
    register_test retvalshouldbe 1
    register_test contain "Empty Directory in PATH (::)"
    run noncompliant path="$PATH::" /opt/debian-cis/bin/hardening/"${script}".sh --audit-all

    describe Tests purposely failing
    register_test retvalshouldbe 1
    register_test contain "Trailing : in PATH"
    run noncompliant path="$PATH:" /opt/debian-cis/bin/hardening/"${script}".sh --audit-all

    describe Tests purposely failing
    register_test retvalshouldbe 1
    register_test contain "PATH contains ."
    run noncompliant path="$PATH:." /opt/debian-cis/bin/hardening/"${script}".sh --audit-all

    describe Tests purposely failing
    mkdir -m 770 "$dir"
    register_test retvalshouldbe 1
    register_test contain "Group Write permission set on directory $dir"
    run noncompliant path="$PATH:$dir" /opt/debian-cis/bin/hardening/"${script}".sh --audit-all
    # clean
    rmdir "$dir"

    describe Tests purposely failing
    mkdir -m 707 "$dir"
    register_test retvalshouldbe 1
    register_test contain "Other Write permission set on directory $dir"
    run noncompliant path="$PATH:$dir" /opt/debian-cis/bin/hardening/"${script}".sh --audit-all
    # clean
    rmdir "$dir"

    describe Tests purposely failing
    useradd "$test_user"
    mkdir -m 700 "$dir"
    chown "$test_user":"$test_user" "$dir"
    register_test retvalshouldbe 1
    register_test contain "$dir is not owned by root"
    run noncompliant path="$PATH:$dir" /opt/debian-cis/bin/hardening/"${script}".sh --audit-all
    # clean
    rmdir "$dir"
    userdel "$test_user"

}
