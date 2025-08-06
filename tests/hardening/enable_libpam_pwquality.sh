# shellcheck shell=bash
# run-shellcheck
test_audit() {
    PATTERN_COMMON='pam_pwquality.so'
    FILE_COMMON='/etc/pam.d/common-password'

    # create issue
    sed -i '/'$PATTERN_COMMON'/d' "$FILE_COMMON"

    describe Running non compliant
    register_test retvalshouldbe 1
    # shellcheck disable=2154
    run noncompliant "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    sed -i 's/audit/enabled/' "${CIS_CONF_DIR}/conf.d/${script}.cfg"
    "${CIS_CHECKS_DIR}/${script}.sh" || true

    describe Checking resolved state
    register_test retvalshouldbe 0
    run resolved "${CIS_CHECKS_DIR}/${script}.sh" --audit-all
}
