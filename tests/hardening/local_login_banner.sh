# shellcheck shell=bash
# run-shellcheck
test_audit() {
    describe Create non-compliant state
    ISSUE_BAK="/tmp/issue.bak.$$"
    if [ -f /etc/issue ]; then
        cp /etc/issue "$ISSUE_BAK"
    fi

    # Create an issue file with OS information patterns
    # Include mingetty escape sequences (\v, \r, \m, \s)
    cat >/etc/issue <<'EOF'
Welcome to \n (\s \m)
Kernel: \r version \v
This is a debian system
EOF

    register_test retvalshouldbe 1
    # shellcheck disable=2154
    run noncompliant "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    describe Correcting situation
    # shellcheck disable=2154
    sed -i 's/audit/enabled/' "${CIS_CONF_DIR}/conf.d/${script}.cfg"
    "${CIS_CHECKS_DIR}/${script}.sh" --apply || true

    describe Re-audit compliant state
    register_test retvalshouldbe 0
    run resolved "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    describe Restore /etc/issue
    if [ -f "$ISSUE_BAK" ]; then
        mv "$ISSUE_BAK" /etc/issue
    else
        rm -f /etc/issue
    fi
    sed -i 's/enabled/audit/' "${CIS_CONF_DIR}/conf.d/${script}.cfg"
}
