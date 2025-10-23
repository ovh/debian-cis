# shellcheck shell=bash
# run-shellcheck
test_audit() {
    describe prepare test
    useradd -M user_no_password
    sed -i 's/user_no_password:!:/user_no_password::/' /etc/shadow

    describe On purpose failing test
    register_test retvalshouldbe 1
    # shellcheck disable=2154
    run failed "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    describe correcting situation using exceptions
    sed -i 's/EXCEPTIONS=.*$/EXCEPTIONS=user_no_password/' "${CIS_CONF_DIR}/conf.d/${script}.cfg"

    describe resolved test
    register_test retvalshouldbe 0
    run resolved "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    describe fix by locking user
    sed -i 's/EXCEPTIONS=.*$/EXCEPTIONS=""/' "${CIS_CONF_DIR}/conf.d/${script}.cfg"
    sed -i 's/audit/enabled/' "${CIS_CONF_DIR}/conf.d/${script}.cfg"
    "${CIS_CHECKS_DIR}/${script}.sh" --apply || true

    describe resolved test
    register_test retvalshouldbe 0
    run resolved "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    describe clean test
    userdel user_no_password

}
