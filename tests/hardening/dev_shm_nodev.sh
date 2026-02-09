# shellcheck shell=bash
# run-shellcheck
test_audit() {
    describe Running on blank host
    register_test retvalshouldbe 0
    dismiss_count_for_test
    # shellcheck disable=2154
    run blank "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    # Try to break it - remove nodev from /dev/shm if present
    describe Tests purposely failing
    if grep -qE '\s/dev/shm\s' /etc/fstab; then
        # Remove nodev option from fstab
        sed -i 's/,nodev//g; s/nodev,//g; s/nodev//g' /etc/fstab
        mount -o remount /dev/shm
    fi
    register_test retvalshouldbe 1
    register_test contain "has no option nodev"
    run noncompliant "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    describe Correcting situation
    sed -i 's/audit/enabled/' "${CIS_CONF_DIR}/conf.d/${script}.cfg"
    "${CIS_CHECKS_DIR}/${script}.sh" --apply || true

    describe Checking resolved state
    register_test retvalshouldbe 0
    register_test contain "has nodev in fstab"
    register_test contain "mounted with nodev"
    run resolved "${CIS_CHECKS_DIR}/${script}.sh" --audit-all
}
