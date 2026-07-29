# shellcheck shell=bash
# run-shellcheck
test_audit() {
    # Skip test if running in a container (mount operations not allowed)
    if [ -f "/.dockerenv" ] || grep -q 'docker\|lxc\|containerd' /proc/1/cgroup 2>/dev/null; then
        skip "Test requires mount operations, skipping in container environment"
        return
    fi

    describe Running on blank host
    register_test retvalshouldbe 0
    # shellcheck disable=2154
    run blank "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    # Backup original fstab
    cp /etc/fstab /tmp/fstab.backup

    # Try to break it - remove nosuid from /dev/shm if present
    describe Tests purposely failing
    if grep -qE '\s/dev/shm\s' /etc/fstab; then
        # Remove nosuid option from fstab
        sed -i 's/,nosuid//g; s/nosuid,//g; s/nosuid//g' /etc/fstab
        mount -o remount /dev/shm
        register_test retvalshouldbe 1
        run noncompliant "${CIS_CHECKS_DIR}/${script}.sh" --audit-all
    else
        skip "/dev/shm not in fstab, skipping noncompliant test"
    fi

    describe Correcting situation
    sed -i 's/audit/enabled/' "${CIS_CONF_DIR}/conf.d/${script}.cfg"
    "${CIS_CHECKS_DIR}/${script}.sh" --apply || true

    describe Checking resolved state
    register_test retvalshouldbe 0
    register_test contain "has nosuid in fstab"
    register_test contain "mounted with nosuid"
    run resolved "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    # Restore original fstab
    mv /tmp/fstab.backup /etc/fstab
    mount -o remount /dev/shm
}
