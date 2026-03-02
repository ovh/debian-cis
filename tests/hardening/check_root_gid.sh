# shellcheck shell=bash
# run-shellcheck
test_audit() {
    if [ "$(id -u)" -ne 0 ]; then
        skip "SKIPPED: root required to manage groups"
        return
    fi

    local group_backup="/tmp/check_root_gid.group.bak"
    local gshadow_backup="/tmp/check_root_gid.gshadow.bak"

    if getent group testgroup_gid0 >/dev/null 2>&1; then
        skip "SKIPPED: test group testgroup_gid0 already exists"
        return
    fi

    cp /etc/group "$group_backup"
    if [ -f /etc/gshadow ]; then
        cp /etc/gshadow "$gshadow_backup"
    fi

    describe Create non-compliant state
    # Create a dedicated test group with GID 0.
    groupadd -g 0 -o testgroup_gid0
    register_test retvalshouldbe 1
    register_test contain "have GID 0"
    # shellcheck disable=2154
    run noncompliant "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    describe Perform documented manual remediation
    # This recommendation is manual-remediation only by design.
    groupdel testgroup_gid0 || true
    # Ensure cleanup of local group files if groupdel did not fully remove the entry.
    sed -i '/^testgroup_gid0:/d' /etc/group
    if [ -f /etc/gshadow ]; then
        sed -i '/^testgroup_gid0:/d' /etc/gshadow
    fi

    describe Re-audit compliant state
    register_test retvalshouldbe 0
    register_test contain "Only root group has GID 0"
    run resolved "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    describe Restore/cleanup
    cp "$group_backup" /etc/group
    rm -f "$group_backup"
    if [ -f "$gshadow_backup" ]; then
        cp "$gshadow_backup" /etc/gshadow
        rm -f "$gshadow_backup"
    fi
}
