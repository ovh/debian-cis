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

    describe Tests purposely failing
    rm -rf /etc/dconf/profile/user
    rm -rf /etc/dconf/db/local.d/00-media-autorun
    rm -rf /etc/dconf/db/local.d/locks/media-autorun
    register_test retvalshouldbe 1
    register_test contain "does not exist"
    run noncompliant "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    describe Correcting situation
    sed -i 's/audit/enabled/' "${CIS_CONF_DIR}/conf.d/${script}.cfg"
    "${CIS_CHECKS_DIR}/${script}.sh" --apply || true

    describe Checking resolved state
    register_test retvalshouldbe 0
    register_test contain "correctly configured"
    register_test contain "correctly set to true"
    register_test contain "is locked"
    run resolved "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    # Cleanup
    apt-get purge -y gdm3 || true
    apt-get autoremove -y || true
    rm -rf /etc/dconf
}
