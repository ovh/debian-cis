# shellcheck shell=bash
# run-shellcheck
test_audit() {
    describe Running on blank host
    register_test retvalshouldbe 0
    dismiss_count_for_test
    # shellcheck disable=2154
    run blank "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    describe Correcting situation
    sed -i 's/audit/enabled/' "${CIS_CONF_DIR}/conf.d/${script}.cfg"
    "${CIS_CHECKS_DIR}/${script}.sh" || true

    describe Checking resolved state
    register_test retvalshouldbe 0
    register_test contain "[ OK ] ^auth[[:space:]]*required[[:space:]]*pam_((tally[2]?)|(faillock))\.so is present in /etc/pam.d/common-auth"
    register_test contain "[ OK ] pam_((tally[2]?)|(faillock))\.so is present in /etc/pam.d/common-account"
    run resolved "${CIS_CHECKS_DIR}/${script}.sh" --audit-all
}
