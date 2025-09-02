# shellcheck shell=bash
# run-shellcheck
test_audit() {

    describe Prepare on purpose failed test
    apt install -y tftpd-hpa
    # running on a container, will can only test the package installation, not the service management

    describe Running on purpose failed test
    register_test retvalshouldbe 1
    # shellcheck disable=2154
    run failed "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    describe correcting situation
    sed -i 's/audit/enabled/' "${CIS_CONF_DIR}/conf.d/${script}.cfg"
    "${CIS_CHECKS_DIR}/${script}.sh" --apply || true

    describe Checking resolved state
    register_test retvalshouldbe 0
    run resolved "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    # we can not test dependencies on trixie, because no package depends from tftpf-hpa
    # we should use the "get_debian_major_version" from lib/utils.sh, but we can't source it in the actual state

    describe clean installation
    apt remove -y tftpd-hpa
    apt autoremove -y

}
