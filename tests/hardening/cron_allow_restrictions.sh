# shellcheck shell=bash
# run-shellcheck
test_audit() {
    describe Test without cron installed
    apt-get purge -y cron || true
    register_test retvalshouldbe 0
    register_test contain "not installed"
    # shellcheck disable=2154
    run no_cron "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    describe Installing cron
    apt-get install -y cron || true

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
    sed -i 's/audit/enabled/' "${CIS_CONF_DIR}/conf.d/${script}.cfg"
    "${CIS_CHECKS_DIR}/${script}.sh" --apply || true

    describe Checking resolved state
    register_test retvalshouldbe 0
    register_test contain "has correct ownership"
    register_test contain "has correct permissions"
    register_test contain "does not exist"
    run resolved "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    # Cleanup
    rm -f /etc/cron.allow /etc/cron.deny
}
