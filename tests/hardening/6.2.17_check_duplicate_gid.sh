# shellcheck shell=bash
# run-shellcheck
test_audit() {
    describe Running on blank host
    register_test retvalshouldbe 0
    dismiss_count_for_test
    # shellcheck disable=2154
    run blank /opt/debian-cis/bin/hardening/"${script}".sh --audit-all

    groupadd -f -g 120 grouptest
    groupadd -fo -g 120 grouptest2

    describe Duplicated groups
    register_test retvalshouldbe 1
    run duplicated /opt/debian-cis/bin/hardening/"${script}".sh --audit-all

    # Cleanup
    groupdel grouptest
    groupdel grouptest2

    describe Compliant state
    register_test retvalshouldbe 0
    run resolved /opt/debian-cis/bin/hardening/"${script}".sh --audit-all

}
