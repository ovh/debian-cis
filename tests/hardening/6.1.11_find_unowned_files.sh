# shellcheck shell=bash
# run-shellcheck
test_audit() {
    describe Running on blank host
    register_test retvalshouldbe 0
    register_test contain "No unowned files found"
    # shellcheck disable=2154
    run blank /opt/debian-cis/bin/hardening/"${script}".sh --audit-all

    describe Tests purposely failing
    local targetfile="/home/secaudit/unowned"
    touch "$targetfile"
    chown 1200 "$targetfile"
    register_test retvalshouldbe 1
    register_test contain "Some unowned files are present"
    run noncompliant /opt/debian-cis/bin/hardening/"${script}".sh --audit-all

    describe correcting situation
    sed -i 's/audit/enabled/' /opt/debian-cis/etc/conf.d/"${script}".cfg
    /opt/debian-cis/bin/hardening/"${script}".sh || true

    describe Checking resolved state
    register_test retvalshouldbe 0
    register_test contain "No unowned files found"
    run resolved /opt/debian-cis/bin/hardening/"${script}".sh --audit-all
}
