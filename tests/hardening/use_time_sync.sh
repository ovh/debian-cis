# shellcheck shell=bash
# run-shellcheck
test_audit() {
    describe prepare test
    apt remove -y systemd-timesyncd ntp chrony

    describe Running on blank host
    register_test retvalshouldbe 1
    # shellcheck disable=2154
    run blank "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    describe Correcting situation
    apt-get update
    apt-get install -y chrony

    # Finally assess that your corrective actions end up with a compliant system
    describe Checking resolved state
    register_test retvalshouldbe 0
    run resolved "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    # we can not check the presence of multiple time synchronization from debian packages, as they are mutually exclusive
    describe clean installation
    apt remove -y chrony
    apt autoremove -y

}
