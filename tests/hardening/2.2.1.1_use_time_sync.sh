# shellcheck shell=bash
# run-shellcheck
test_audit() {
    describe Running on blank host
    register_test retvalshouldbe 1
    dismiss_count_for_test
    # shellcheck disable=2154
    run blank /opt/debian-cis/bin/hardening/"${script}".sh --audit-all

    describe Correcting situation
    apt-get update
    apt-get install -y ntp

    # Finally assess that your corrective actions end up with a compliant system
    describe Checking resolved state
    register_test retvalshouldbe 0
    register_test contain "Time synchronization is available through"
    run resolved /opt/debian-cis/bin/hardening/"${script}".sh --audit-all
}
