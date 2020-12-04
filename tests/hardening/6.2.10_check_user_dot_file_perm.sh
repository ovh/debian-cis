# shellcheck shell=bash
# run-shellcheck
test_audit() {
    describe Running on blank host
    register_test retvalshouldbe 0
    dismiss_count_for_test
    # shellcheck disable=2154
    run blank /opt/debian-cis/bin/hardening/"${script}".sh --audit-all

    local test_user="testdotuser"
    local test_file=".test"

    describe Tests purposely failing
    useradd --create-home "$test_user"
    touch "/home/$test_user/$test_file"
    chmod 777 "/home/$test_user/$test_file"
    register_test retvalshouldbe 1
    register_test contain "Group Write permission set on FILE"
    register_test contain "Other Write permission set on FILE"
    run noncompliant /opt/debian-cis/bin/hardening/"${script}".sh --audit-all

    describe correcting situation
    sed -i 's/audit/enabled/' /opt/debian-cis/etc/conf.d/"${script}".cfg
    /opt/debian-cis/bin/hardening/"${script}".sh --apply || true

    describe Checking resolved state
    register_test retvalshouldbe 0
    register_test contain "Dot file permission in users directories are correct"
    run resolved /opt/debian-cis/bin/hardening/"${script}".sh --audit-all

    # cleanup
    userdel -r "$test_user"
}
