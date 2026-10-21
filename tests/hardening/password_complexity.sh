# shellcheck shell=bash
# run-shellcheck
test_audit() {

    local OPTIONS="minclass=3 dcredit=-1 ucredit=-2 ocredit=-1 lcredit=-1"
    local FILE_QUALITY='/etc/security/pwquality.conf'

    # install dependencies
    apt-get update
    apt-get install -y libpam-pwquality

    # prepare to fail
    describe Prepare on purpose failed test
    sed -i '/minclass/d' "$FILE_QUALITY"
    printf '%s\n' 'password requisite pam_pwquality.so minclass=2 dcredit=-1 ucredit=-2 ocredit=-1 lcredit=-1' >>/etc/pam.d/common-password

    describe Running on purpose failed test
    register_test retvalshouldbe 1
    # shellcheck disable=2154
    run blank "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    describe Correcting situation
    sed -E -i 's/minclass[[:space:]]*=[[:space:]]*[-0-9]+//g' /etc/pam.d/common-password
    echo "$OPTIONS" >>"$FILE_QUALITY"

    describe Checking resolved state
    register_test retvalshouldbe 0
    run resolved "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

}
