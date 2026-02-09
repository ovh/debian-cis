# shellcheck shell=bash
# run-shellcheck
test_audit() {
    describe Test without GDM installed
    apt-get purge -y gdm3 || true
    apt-get autoremove -y || true
    register_test retvalshouldbe 0
    register_test contain "not installed"
    # shellcheck disable=2154
    run no_gdm "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    describe Installing GDM
    apt-get install -y gdm3 || true

    describe Tests purposely failing - enabling XDMCP
    # Add XDMCP enable to config
    if [ -f /etc/gdm3/custom.conf ]; then
        echo -e "\n[xdmcp]\nEnable=true" >>/etc/gdm3/custom.conf
    elif [ -f /etc/gdm3/daemon.conf ]; then
        echo -e "\n[xdmcp]\nEnable=true" >>/etc/gdm3/daemon.conf
    fi
    register_test retvalshouldbe 1
    register_test contain "XDMCP is enabled"
    run noncompliant "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    describe Correcting situation
    sed -i 's/audit/enabled/' "${CIS_CONF_DIR}/conf.d/${script}.cfg"
    "${CIS_CHECKS_DIR}/${script}.sh" --apply || true

    describe Checking resolved state
    register_test retvalshouldbe 0
    register_test contain "not enabled"
    run resolved "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    # Cleanup
    apt-get purge -y gdm3 || true
    apt-get autoremove -y || true
}
