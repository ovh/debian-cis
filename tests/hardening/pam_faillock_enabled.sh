# shellcheck shell=bash
# run-shellcheck
test_audit() {

    local PAM_FILES=""
    PAM_FILES="/etc/pam.d/common-auth /etc/pam.d/common-account"

    # install dependencies
    apt-get update
    apt-get install -y libpam-pwquality

    # prepare to fail
    describe Prepare on purpose failed test
    # shellcheck disable=2086
    sed -i '/pam_faillock.so/s/^/#/g' $PAM_FILES

    describe Running on purpose failed test
    register_test retvalshouldbe 1
    # shellcheck disable=2154
    run blank "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    describe correcting situation
    sed -i 's/audit/enabled/' "${CIS_CONF_DIR}/conf.d/${script}.cfg"
    "${CIS_CHECKS_DIR}/${script}.sh" --apply || true

    describe Checking resolved state
    register_test retvalshouldbe 0
    run resolved "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

}
