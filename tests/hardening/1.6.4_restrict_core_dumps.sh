# shellcheck shell=bash
# run-shellcheck
test_audit() {
    if [ -f "/.dockerenv" ]; then
        skip "SKIPPED on docker"
    else
        describe Running on blank host
        register_test retvalshouldbe 0
        dismiss_count_for_test
        # shellcheck disable=2154
        run blank /opt/debian-cis/bin/hardening/"${script}".sh --audit-all

    # TODO fill comprehensive tests
    fi
}
