# shellcheck shell=bash
# run-shellcheck
test_audit() {
    describe Prepare exceptions tests
    apt install -y netcat-traditional

    # shellcheck disable=2216
    timeout 5s nc -lp 22 | true &

    describe Running succesfull check
    register_test retvalshouldbe 0
    # shellcheck disable=2154
    run success "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    describe Prepare on purpose failing tests
    # shellcheck disable=2216
    timeout 5s nc -lp 80 | true &

    describe Running failed check
    register_test retvalshouldbe 1
    # shellcheck disable=2154
    run failed "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    describe correcting situation
    # just wait for timeout to expire
    sleep 5

    describe Checking resolved state
    register_test retvalshouldbe 0
    run resolved "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    describe clean installation
    apt remove -y netcat-traditional
    apt autoremove -y

}
