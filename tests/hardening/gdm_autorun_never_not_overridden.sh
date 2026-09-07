# shellcheck shell=bash
# run-shellcheck
test_audit() {
    describe Installing GDM
    DEBIAN_FRONTEND=noninteractive apt-get install -y gdm3 -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" || true

    describe Create non-compliant state
    mkdir -p /etc/dconf/db/local.d/locks
    cat >/etc/dconf/db/local.d/00-media-autorun <<'EOF'
[org/gnome/desktop/media-handling]
autorun-never=true
EOF
    : >/etc/dconf/db/local.d/locks/00-media-autorun

    register_test retvalshouldbe 1
    register_test contain "not locked"
    # shellcheck disable=2154
    run noncompliant "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    describe Correcting situation
    sed -i 's/audit/enabled/' "${CIS_CONF_DIR}/conf.d/${script}.cfg"
    "${CIS_CHECKS_DIR}/${script}.sh" --apply || true

    describe Re-audit compliant state
    register_test retvalshouldbe 0
    register_test contain "setting found"
    register_test contain "is locked"
    # shellcheck disable=2154
    run resolved "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    describe Restore/cleanup
    rm -f /etc/dconf/db/local.d/00-media-autorun /etc/dconf/db/local.d/locks/00-media-autorun

    DEBIAN_FRONTEND=noninteractive apt-get remove -y gdm3 || true
    DEBIAN_FRONTEND=noninteractive apt-get autoremove -y || true
}
