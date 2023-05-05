# shellcheck shell=bash
# run-shellcheck
test_audit() {
    describe Running on blank host
    register_test retvalshouldbe 0
    dismiss_count_for_test
    # shellcheck disable=2154
    run blank /opt/debian-cis/bin/hardening/"${script}".sh --audit-all

    describe Correcting situation
    sed -i 's/audit/enabled/' /opt/debian-cis/etc/conf.d/"${script}".cfg
    /opt/debian-cis/bin/hardening/"${script}".sh || true

    describe Checking resolved state
    register_test retvalshouldbe 0
    register_test contain "[ OK ] -w /sbin/rmmod -p x -k modules is present in /etc/audit/rules.d/audit.rules"
    register_test contain "[ OK ] -w /sbin/modprobe -p x -k modules is present in /etc/audit/rules.d/audit.rules"
    register_test contain "[ OK ] -a always,exit -F arch=b64 -S init_module -S delete_module -k modules is present in /etc/audit/rules.d/audit.rules"
    run resolved /opt/debian-cis/bin/hardening/"${script}".sh --audit-all
}
