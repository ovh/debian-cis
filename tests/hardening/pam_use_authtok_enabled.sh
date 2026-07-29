# shellcheck shell=bash
# run-shellcheck
test_audit() {

    # install dependencies
    apt-get update
    apt-get install -y libpam-pwquality

    describe Prepare on purpose failed test
    cp /usr/share/pam-configs/unix /tmp/pam_config_unix.save
    sed -i 's/use_authtok//g' /usr/share/pam-configs/unix /etc/pam.d/common-password

    describe Running on purpose failed test
    register_test retvalshouldbe 1
    # shellcheck disable=2154
    run failed "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    describe fix situation
    sed -i 's/audit/enabled/' "${CIS_CONF_DIR}/conf.d/${script}.cfg"
    "${CIS_CHECKS_DIR}/${script}.sh" --apply || true

    describe Checking resolved state
    register_test retvalshouldbe 0
    run resolved "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    describe clean test
    cp /tmp/pam_config_unix.save /usr/share/pam-configs/unix

}
