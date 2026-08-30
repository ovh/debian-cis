# shellcheck shell=bash
# run-shellcheck
test_audit() {
    describe Prepare tests
    apt install -y netcat-traditional

    # shellcheck disable=2216
    describe Prepare on purpose failing tests
    # shellcheck disable=2216
    timeout 5s nc -lp 25 | true &

    describe Running failed check
    register_test retvalshouldbe 1
    # shellcheck disable=2154
    run failed "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    describe add aditiona MTA port to check
    # ensure previous test is finished
    sleep 5
    echo status=audit >"${CIS_CONF_DIR}/conf.d/${script}.cfg"
    echo 'MTA_PORTS="25 465"' >>"${CIS_CONF_DIR}/conf.d/${script}.cfg"
    timeout 5s nc -lp 465 | true &
    describe Running failed check with additional port
    register_test retvalshouldbe 1
    # shellcheck disable=2154
    run failed "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    # ensure previous test is finished
    sleep 5
    describe Running successful check
    register_test retvalshouldbe 0
    # shellcheck disable=2154
    run success "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    describe listening on localhost only
    # shellcheck disable=2216
    timeout 5s nc -s 127.0.0.1 -lp 25 | true &

    describe Running successful check
    register_test retvalshouldbe 0
    # shellcheck disable=2154
    run success "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    # ensure previous test is finished
    sleep 5

    describe clean installation
    apt remove -y netcat-traditional
    apt autoremove -y
}
