# shellcheck shell=bash
# run-shellcheck
test_audit() {
    # current value may differ among the OS
    local current_value
    current_value=$(sysctl kernel.yama.ptrace_scope | awk -F '=' '{print $2}' | sed 's/\ //g')

    if [ "$current_value" -eq 1 ]; then
        # can only test audit here, unless running on a privileged container
        describe Running successfull test
        register_test retvalshouldbe 0
        # shellcheck disable=2154
        run blank "${CIS_CHECKS_DIR}/${script}.sh" --audit-all
    else
        # can only test audit here, unless running on a privileged container
        describe Running failed test
        register_test retvalshouldbe 1
        # shellcheck disable=2154
        run blank "${CIS_CHECKS_DIR}/${script}.sh" --audit-all
    fi
}
