# shellcheck shell=bash
# run-shellcheck
test_audit() {
    # shellcheck disable=2154
    local script_cfg="${CIS_CONF_DIR}/conf.d/${script}.cfg"
    local cfg_backup="/tmp/cron_allow_restrictions.cfg.bak.$$"
    local cfg_existed=1
    local custom_group='ciscrongrp'
    local custom_user='ciscronusr'

    describe Test without cron installed
    apt-get purge -y cron || true
    register_test retvalshouldbe 0
    register_test contain "not installed"
    # shellcheck disable=2154
    run no_cron "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    describe Installing cron
    apt-get install -y cron || true

    if [ -f "$script_cfg" ]; then
        cp "$script_cfg" "$cfg_backup"
    else
        cfg_existed=0
    fi

    # Backup original files if they exist
    if [ -f /etc/cron.allow ]; then
        cp /etc/cron.allow /tmp/cron.allow.bak
    fi
    if [ -f /etc/cron.deny ]; then
        cp /etc/cron.deny /tmp/cron.deny.bak
    fi

    describe Tests purposely failing - missing cron.allow
    rm -f /etc/cron.allow
    touch /etc/cron.deny
    register_test retvalshouldbe 1
    register_test contain "does not exist"
    run noncompliant_missing "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    describe Tests purposely failing - wrong permissions
    touch /etc/cron.allow
    chmod 777 /etc/cron.allow
    chown nobody:nogroup /etc/cron.allow
    register_test retvalshouldbe 1
    register_test contain "permissions are not"
    run noncompliant_perms "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    describe Correcting situation
    sed -i 's/audit/enabled/' "$script_cfg"
    "${CIS_CHECKS_DIR}/${script}.sh" --apply || true

    describe Checking resolved state
    register_test retvalshouldbe 0
    register_test contain "has correct ownership"
    register_test contain "has correct permissions"
    register_test contain "does not exist"
    run resolved "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    describe Testing configurable user/group
    groupadd "$custom_group" 2>/dev/null || true
    id "$custom_user" >/dev/null 2>&1 || useradd -M -g "$custom_group" -s /usr/sbin/nologin "$custom_user"
    sed -i '/^CRON_ALLOW_USER=/d' "$script_cfg"
    sed -i '/^CRON_ALLOW_GROUP=/d' "$script_cfg"
    echo "CRON_ALLOW_USER='$custom_user'" >>"$script_cfg"
    echo "CRON_ALLOW_GROUP='$custom_group'" >>"$script_cfg"

    touch /etc/cron.allow
    chmod 777 /etc/cron.allow
    chown root:root /etc/cron.allow
    touch /etc/cron.deny

    "${CIS_CHECKS_DIR}/${script}.sh" --apply || true

    register_test retvalshouldbe 0
    register_test contain "has correct ownership"
    register_test contain "has correct permissions"
    run resolved_custom_owner_group "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    # Cleanup
    rm -f /etc/cron.allow /etc/cron.deny

    # Restore original files if they existed
    if [ -f /tmp/cron.allow.bak ]; then
        mv /tmp/cron.allow.bak /etc/cron.allow
    fi
    if [ -f /tmp/cron.deny.bak ]; then
        mv /tmp/cron.deny.bak /etc/cron.deny
    fi

    if [ "$cfg_existed" -eq 1 ]; then
        mv "$cfg_backup" "$script_cfg"
    else
        rm -f "$script_cfg"
    fi

    userdel "$custom_user" 2>/dev/null || true
    groupdel "$custom_group" 2>/dev/null || true

    # Remove cron package and cleanup
    apt-get purge -y cron
    apt-get autoremove -y
}
