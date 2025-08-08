# shellcheck shell=bash
# run-shellcheck
test_audit() {

    describe Ensure package is installed

    # install dependencies
    apt update
    apt install -y systemd-timesyncd

    # not much to test here, we are running in a container, we wont check service state
    describe Checking blank host
    register_test retvalshouldbe 0
    # shellcheck disable=2154
    run blank "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    apt remove -y systemd-timesyncd
    apt autoremove -y

}
