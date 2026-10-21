# shellcheck shell=bash
# run-shellcheck
test_audit() {

    local OPTIONS="minclass=3 dcredit=-1 ucredit=-2 ocredit=-1 lcredit=-1"
    local FILE_QUALITY='/etc/security/pwquality.conf'
    local pwquality_profile='/usr/share/pam-configs/pwquality'
    local option

    # install dependencies
    apt-get update
    apt-get install -y libpam-pwquality
    cp "$FILE_QUALITY" /tmp/pwquality.conf.bak

    describe Prepare on purpose failed test: options not set
    sed -E -i '/^[[:space:]]?(minclass|dcredit|ucredit|ocredit|lcredit)/d' "$FILE_QUALITY"
    register_test retvalshouldbe 1
    # shellcheck disable=2154
    run noconf "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    describe Correcting situation
    # pwquality.conf is not modified by apply(), it has to be configured manually
    for option in $OPTIONS; do
        echo "$option" >>"$FILE_QUALITY"
    done

    describe Checking resolved state
    register_test retvalshouldbe 0
    run resolved_conf "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    describe Prepare on purpose failed test: wrong value in pam-auth-update profile
    sed -i -E 's/(pam_pwquality\.so.*)$/\1 minclass=2/' "$pwquality_profile"
    DEBIAN_FRONTEND='noninteractive' pam-auth-update --force --enable pwquality
    register_test retvalshouldbe 1
    run profile "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    describe correcting situation
    sed -i 's/audit/enabled/' "${CIS_CONF_DIR}/conf.d/${script}.cfg"
    "${CIS_CHECKS_DIR}/${script}.sh" --apply || true

    describe Checking resolved state
    register_test retvalshouldbe 0
    run resolved_profile "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    describe Prepare on purpose failed test: wrong value in /etc/pam.d
    printf '%s\n' 'password requisite pam_pwquality.so minclass=2 dcredit=-1 ucredit=-2 ocredit=-1 lcredit=-1' >>/etc/pam.d/common-password
    register_test retvalshouldbe 1
    run pamd "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    describe correcting situation
    "${CIS_CHECKS_DIR}/${script}.sh" --apply || true

    describe Checking resolved state
    register_test retvalshouldbe 0
    run resolved_pamd "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    describe clean test
    mv /tmp/pwquality.conf.bak "$FILE_QUALITY"
    DEBIAN_FRONTEND='noninteractive' pam-auth-update --force
    apt-get remove -y libpam-pwquality

}
