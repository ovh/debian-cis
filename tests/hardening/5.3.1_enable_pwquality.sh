# shellcheck shell=bash
# run-shellcheck
test_audit() {

    apt-get update
    apt-get install -y libpam-pwquality

    describe Running on blank host
    register_test retvalshouldbe 1
    register_test contain "libpam-pwquality is installed"
    # shellcheck disable=2154
    run blank /opt/debian-cis/bin/hardening/"${script}".sh --audit-all

    describe Correcting situation
    sed -i 's/audit/enabled/' /opt/debian-cis/etc/conf.d/"${script}".cfg
    /opt/debian-cis/bin/hardening/"${script}".sh || true

    describe Checking resolved state
    register_test retvalshouldbe 0
    register_test contain "[ OK ] pam_pwquality.so is present in /etc/pam.d/common-password"
    register_test contain "[ OK ] ^minlen[[:space:]]+=[[:space:]]+14 is present in /etc/security/pwquality.conf"
    register_test contain "[ OK ] ^dcredit[[:space:]]+=[[:space:]]+-1 is present in /etc/security/pwquality.conf"
    register_test contain "[ OK ] ^ucredit[[:space:]]+=[[:space:]]+-1 is present in /etc/security/pwquality.conf"
    register_test contain "[ OK ] ^ocredit[[:space:]]+=[[:space:]]+-1 is present in /etc/security/pwquality.conf"
    register_test contain "[ OK ] ^lcredit[[:space:]]+=[[:space:]]+-1 is present in /etc/security/pwquality.con"
    run resolved /opt/debian-cis/bin/hardening/"${script}".sh --audit-all
}
