# shellcheck shell=bash
# run-shellcheck
test_audit() {
    describe Running on blank host
    register_test retvalshouldbe 0
    dismiss_count_for_test
    # shellcheck disable=2154
    run blank /opt/debian-cis/bin/hardening/"${script}".sh --audit-all

    local test_user="testcrontabduser"

    describe Tests purposely failing
    touch /etc/cron.deny /etc/at.deny
    register_test retvalshouldbe 1
    register_test contain "/etc/cron.deny exists"
    register_test contain "/etc/at.deny exists"
    run noncompliant /opt/debian-cis/bin/hardening/"${script}".sh --audit-all

    describe correcting situation
    sed -i 's/audit/enabled/' /opt/debian-cis/etc/conf.d/"${script}".cfg
    /opt/debian-cis/bin/hardening/"${script}".sh --apply || true

    touch /etc/cron.allow /etc/at.allow
    describe Tests purposely failing
    useradd "$test_user"
    chown "$test_user":"$test_user" /etc/cron.allow
    chown "$test_user":"$test_user" /etc/at.allow
    register_test retvalshouldbe 1
    register_test contain "/etc/cron.allow ownership was not set to"
    register_test contain "/etc/at.allow ownership was not set to"
    run noncompliant /opt/debian-cis/bin/hardening/"${script}".sh --audit-all
    userdel "$test_user"

    describe correcting situation
    sed -i 's/audit/enabled/' /opt/debian-cis/etc/conf.d/"${script}".cfg
    /opt/debian-cis/bin/hardening/"${script}".sh --apply || true

    describe Tests purposely failing
    useradd "$test_user"
    chmod 777 /etc/cron.allow
    chmod 777 /etc/at.allow
    register_test retvalshouldbe 1
    register_test contain "/etc/cron.allow permissions were not set to"
    register_test contain "/etc/at.allow permissions were not set to"
    run noncompliant /opt/debian-cis/bin/hardening/"${script}".sh --audit-all
    userdel "$test_user"

    describe correcting situation
    sed -i 's/audit/enabled/' /opt/debian-cis/etc/conf.d/"${script}".cfg
    /opt/debian-cis/bin/hardening/"${script}".sh --apply || true

    describe Checking resolved state
    register_test retvalshouldbe 0
    register_test contain "/etc/cron.allow has correct permissions"
    register_test contain "/etc/cron.allow has correct ownership"
    register_test contain "/etc/at.allow has correct permissions"
    register_test contain "/etc/at.allow has correct ownership"
    run resolved /opt/debian-cis/bin/hardening/"${script}".sh --audit-all

}
