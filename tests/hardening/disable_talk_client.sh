# shellcheck shell=bash
# run-shellcheck
test_audit() {
    local test_pkg=''

    describe Installing a talk client for tests
    apt-get update >/dev/null 2>&1 || true
    for candidate in talk inetutils-talk; do
        if DEBIAN_FRONTEND='noninteractive' apt-get install -y "$candidate" >/dev/null 2>&1; then
            test_pkg="$candidate"
            break
        fi
    done
    if [ -z "$test_pkg" ]; then
        skip "Cannot install any supported talk client, skipping tests"
        return
    fi

    describe Create non-compliant state
    register_test retvalshouldbe 1
    # shellcheck disable=2154
    run noncompliant "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    describe Correcting situation
    sed -i 's/audit/enabled/' "${CIS_CONF_DIR}/conf.d/${script}.cfg"
    "${CIS_CHECKS_DIR}/${script}.sh" || true

    describe Re-audit compliant state
    register_test retvalshouldbe 0
    run resolved "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    describe Cleanup
    apt-get purge -y "$test_pkg" >/dev/null 2>&1 || true
    apt-get autoremove -y >/dev/null 2>&1 || true
}
