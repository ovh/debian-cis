# shellcheck shell=bash
# run-shellcheck
test_audit() {
    describe Running on blank host
    register_test retvalshouldbe 0
    dismiss_count_for_test
    # shellcheck disable=2154
    run blank /opt/debian-cis/bin/hardening/"${script}".sh --audit-all

    echo "TMOUT=600" >/etc/profile.d/CIS_99.1_timeout.sh

    describe compliant
    register_test retvalshouldbe 0
    run compliant /opt/debian-cis/bin/hardening/"${script}".sh --audit-all

    # TODO fill comprehensive tests

    # Cleanup
    rm /etc/profile.d/CIS_99.1_timeout.sh
}
