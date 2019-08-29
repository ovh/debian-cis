# run-shellcheck
test_audit() {
    # Make all variable local to the function by using `local`

    describe Running on blank host
    register_test retvalshouldbe 1
    register_test contain "None of the following time sync packages are installed"
    run blank /opt/debian-cis/bin/hardening/"${script}".sh --audit-all

    describe Correcting situation
    apt update
    apt install -y ntp

    # Finally assess that your corrective actions end up with a compliant system
    describe Checking resolved state
    register_test retvalshouldbe 0
    register_test contain "Time synchronization is available through"
    run resolved /opt/debian-cis/bin/hardening/"${script}".sh --audit-all
}

