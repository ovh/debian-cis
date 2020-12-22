# shellcheck shell=bash
# run-shellcheck
test_audit() {
    describe Running on blank host
    register_test retvalshouldbe 0
    dismiss_count_for_test
    # shellcheck disable=2154
    run blank /opt/debian-cis/bin/hardening/"${script}".sh --audit-all

    local test_user="testetcshadowusr"

    describe Tests purposely failing
    useradd "$test_user"
    sed -i "s/$test_user:/+:$test_user:/" /etc/shadow
    register_test retvalshouldbe 1
    register_test contain "Some accounts have a legacy password entry"
    run noncompliant /opt/debian-cis/bin/hardening/"${script}".sh --audit-all

    describe correcting situation
    sed -i 's/audit/enabled/' /opt/debian-cis/etc/conf.d/"${script}".cfg
    /opt/debian-cis/bin/hardening/"${script}".sh --apply || true

    describe Checking resolved state
    register_test retvalshouldbe 0
    register_test contain "All accounts have a valid password entry format"
    run resolved /opt/debian-cis/bin/hardening/"${script}".sh --audit-all

    # cleanup
    userdel "$test_user"

}
