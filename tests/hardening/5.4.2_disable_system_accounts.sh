# shellcheck shell=bash
# run-shellcheck
test_audit() {
    cp -a /etc/passwd /tmp/passwd.bak

    describe Running on blank host
    register_test retvalshouldbe 1
    # shellcheck disable=2154
    run blank /opt/debian-cis/bin/hardening/"${script}".sh --audit-all

    describe correcting situation
    sed -i 's/audit/enabled/' /opt/debian-cis/etc/conf.d/"${script}".cfg
    /opt/debian-cis/bin/hardening/"${script}".sh --apply || true

    describe Checking resolved state
    register_test retvalshouldbe 0
    run resolved /opt/debian-cis/bin/hardening/"${script}".sh --audit-all

    mv /tmp/passwd.bak /etc/passwd
}
