# shellcheck shell=bash
# run-shellcheck
test_audit() {
    if ! apt-cache show prelink 2>/dev/null | grep -q '^Package: prelink$'; then
        skip "prelink package is not available in this environment"
        return
    fi

    DEBIAN_FRONTEND=noninteractive apt-get install -y prelink >/dev/null 2>&1 || {
        skip "Unable to install prelink package"
        return
    }

    describe prelink installed
    register_test retvalshouldbe 1
    # shellcheck disable=2154
    run noncompliant "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    # shellcheck disable=2154
    sed -i 's/audit/enabled/' "${CIS_CONF_DIR}/conf.d/${script}.cfg"
    # shellcheck disable=2154
    "${CIS_CHECKS_DIR}/${script}.sh" --apply || true

    describe prelink removed
    register_test retvalshouldbe 0
    # shellcheck disable=2154
    run resolved "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    apt-get purge -y prelink >/dev/null 2>&1 || true
    apt-get autoremove -y >/dev/null 2>&1 || true
}
