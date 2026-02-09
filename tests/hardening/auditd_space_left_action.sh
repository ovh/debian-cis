# shellcheck shell=bash
# run-shellcheck
test_audit() {
    describe Configure the check
    # shellcheck disable=2154
    echo "SPACE_LEFT_ACTION='email'" >>"${CIS_CONF_DIR}/conf.d/${script}.cfg"
    echo "ADMIN_SPACE_LEFT_ACTION='halt'" >>"${CIS_CONF_DIR}/conf.d/${script}.cfg"

    describe Tests purposely failing
    if [ -f /etc/audit/auditd.conf ]; then
        sed -i '/^space_left_action/d' /etc/audit/auditd.conf
        sed -i '/^admin_space_left_action/d' /etc/audit/auditd.conf
    fi
    register_test retvalshouldbe 1
    register_test contain "not set to"
    # shellcheck disable=2154
    run noncompliant "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    describe Correcting situation
    sed -i 's/audit/enabled/' "${CIS_CONF_DIR}/conf.d/${script}.cfg"
    "${CIS_CHECKS_DIR}/${script}.sh" --apply || true

    describe Checking resolved state
    register_test retvalshouldbe 0
    register_test contain "correctly set"
    run resolved "${CIS_CHECKS_DIR}/${script}.sh" --audit-all
}
