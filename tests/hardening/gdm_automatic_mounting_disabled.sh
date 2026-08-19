# shellcheck shell=bash
# run-shellcheck
test_audit() {
    describe Installing GDM
    DEBIAN_FRONTEND=noninteractive apt-get install -y gdm3 -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" || true

    describe Create non-compliant state
    rm -f /etc/dconf/db/local.d/00-media-automount
    register_test retvalshouldbe 1
    # shellcheck disable=2154
    run noncompliant "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    describe Correcting situation
    sed -i 's/audit/enabled/' "${CIS_CONF_DIR}/conf.d/${script}.cfg"
    "${CIS_CHECKS_DIR}/${script}.sh" --apply || true

    describe Re-audit compliant state
    register_test retvalshouldbe 0
    register_test contain "automount is set to false"
    register_test contain "automount-open is set to false"
    # shellcheck disable=2154
    run resolved "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    describe Restore/cleanup
    rm -f /etc/dconf/db/local.d/00-media-automount

    DEBIAN_FRONTEND=noninteractive apt-get remove -y gdm3 || true
    DEBIAN_FRONTEND=noninteractive apt-get autoremove -y || true
}
