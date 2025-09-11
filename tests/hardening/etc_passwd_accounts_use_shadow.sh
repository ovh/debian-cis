# shellcheck shell=bash
# run-shellcheck
test_audit() {
    describe prepare test
    useradd -M user_no_shadow
    sed -i 's/user_no_shadow:x:/user_no_shadow:foobar:/' /etc/passwd

    describe On purpose failing test
    register_test retvalshouldbe 1
    # shellcheck disable=2154
    run failed "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    describe correcting situation
    sed -i 's/EXCEPTIONS=.*$/EXCEPTIONS=user_no_shadow/' "${CIS_CONF_DIR}/conf.d/${script}.cfg"

    describe resolved test
    register_test retvalshouldbe 0
    run resolved "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    describe clean test
    userdel user_no_shadow
    sed -i 's/EXCEPTIONS=.*$/EXCEPTIONS=""/' "${CIS_CONF_DIR}/conf.d/${script}.cfg"
}
