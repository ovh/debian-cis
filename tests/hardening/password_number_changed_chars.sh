# shellcheck shell=bash
# run-shellcheck
test_audit() {

    local pwquality_conf='/etc/security/pwquality.conf'
    local pwquality_profile='/usr/share/pam-configs/pwquality'

    apt-get install -y libpam-pwquality
    cp "$pwquality_conf" /tmp/pwquality.conf.bak

    describe Prepare on purpose failed test: difok not set
    sed -E -i '/^[[:space:]]?difok/d' "$pwquality_conf"
    register_test retvalshouldbe 1
    # shellcheck disable=2154
    run noconf "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    describe Checking a value higher than the minimum is compliant
    echo "difok = 5" >>"$pwquality_conf"
    register_test retvalshouldbe 0
    run higher "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    describe Prepare on purpose failed test: wrong value in pam-auth-update profile
    sed -i -E 's/(pam_pwquality\.so.*)$/\1 difok=1/' "$pwquality_profile"
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
    printf '%s\n' 'password requisite pam_pwquality.so difok=1' >>/etc/pam.d/common-password
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
