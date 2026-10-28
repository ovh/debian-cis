# shellcheck shell=bash
# run-shellcheck
test_audit() {

    local pwquality_conf='/etc/security/pwquality.conf'
    local pwquality_profile='/usr/share/pam-configs/pwquality'

    apt-get install -y libpam-pwquality
    cp "$pwquality_conf" /tmp/pwquality.conf.bak

    describe Prepare on purpose failed test: dictcheck not set
    sed -E -i '/^[[:space:]]?dictcheck/d' "$pwquality_conf"
    register_test retvalshouldbe 1
    # shellcheck disable=2154
    run noconf "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    describe Prepare on purpose failed test: dictcheck disabled in pam-auth-update profile
    echo "dictcheck = 1" >>"$pwquality_conf"
    sed -i -E 's/(pam_pwquality\.so.*)$/\1 dictcheck=0/' "$pwquality_profile"
    DEBIAN_FRONTEND='noninteractive' pam-auth-update --force --enable pwquality
    register_test retvalshouldbe 1
    run profile "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    describe correcting situation
    sed -i 's/audit/enabled/' "${CIS_CONF_DIR}/conf.d/${script}.cfg"
    "${CIS_CHECKS_DIR}/${script}.sh" --apply || true

    describe Checking resolved state
    register_test retvalshouldbe 0
    run resolved_profile "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    describe Prepare on purpose failed test: dictcheck disabled in /etc/pam.d
    printf '%s\n' 'password requisite pam_pwquality.so dictcheck=0' >>/etc/pam.d/common-password
    register_test retvalshouldbe 1
    run pamd "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    describe correcting situation
    "${CIS_CHECKS_DIR}/${script}.sh" --apply || true

    describe Checking resolved state
    register_test retvalshouldbe 0
    run resolved_pamd "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    describe clean test
    mv /tmp/pwquality.conf.bak "$pwquality_conf"
    DEBIAN_FRONTEND='noninteractive' pam-auth-update --force
    apt-get remove -y libpam-pwquality

}
