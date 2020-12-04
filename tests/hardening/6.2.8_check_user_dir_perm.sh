# shellcheck shell=bash
# run-shellcheck
test_audit() {
    describe Running on blank host
    register_test retvalshouldbe 0
    dismiss_count_for_test
    # shellcheck disable=2154
    run blank /opt/debian-cis/bin/hardening/"${script}".sh --audit-all

    local test_user="testhomepermuser"

    describe Tests purposely failing
    useradd --create-home "$test_user"
    chmod 777 /home/"$test_user"
    register_test retvalshouldbe 1
    register_test contain "Group Write permission set on directory"
    register_test contain "Other Read permission set on directory"
    register_test contain "Other Write permission set on directory"
    register_test contain "Other Execute permission set on directory"

    run noncompliant /opt/debian-cis/bin/hardening/"${script}".sh --audit-all

    describe correcting situation
    sed -i 's/audit/enabled/' /opt/debian-cis/etc/conf.d/"${script}".cfg
    /opt/debian-cis/bin/hardening/"${script}".sh --apply || true

    describe Checking resolved state
    register_test retvalshouldbe 0
    register_test contain "No incorrect permissions on home directories"
    run resolved /opt/debian-cis/bin/hardening/"${script}".sh --audit-all

    # cleanup
    userdel -r "$test_user"
}
