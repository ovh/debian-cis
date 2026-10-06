# shellcheck shell=bash
# run-shellcheck
test_audit() {
    describe Installing dovecot packages
    DEBIAN_FRONTEND=noninteractive apt-get install -y dovecot-imapd dovecot-pop3d || true

    describe Create non-compliant state
    register_test retvalshouldbe 1
    register_test contain "is installed"
    # shellcheck disable=2154
    run noncompliant "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    describe Correcting situation
    sed -i 's/audit/enabled/' "${CIS_CONF_DIR}/conf.d/${script}.cfg"
    "${CIS_CHECKS_DIR}/${script}.sh" --apply || true

    describe Re-audit compliant state
    register_test retvalshouldbe 0
    register_test contain "not installed"
    # shellcheck disable=2154
    run resolved "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    describe Restore/cleanup
    DEBIAN_FRONTEND=noninteractive apt-get purge -y dovecot-imapd dovecot-pop3d || true
    DEBIAN_FRONTEND=noninteractive apt-get autoremove -y || true
}
