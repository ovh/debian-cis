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
    fi
    ##################################################################
    # For this test, we only check that it runs properly on a blank  #
    # host, and we check root/sudo consistency. But, we don't test   #
    # the apply function because it can't be automated or it is very #
    # long to test and not very useful.                              #
    ##################################################################
}
