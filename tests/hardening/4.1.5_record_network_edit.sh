# shellcheck shell=bash
# run-shellcheck
test_audit() {
    describe Running on blank host
    register_test retvalshouldbe 0
    dismiss_count_for_test
    # shellcheck disable=2154
    run blank /opt/debian-cis/bin/hardening/"${script}".sh --audit-all

    describe Correcting situation
    sed -i 's/audit/enabled/' /opt/debian-cis/etc/conf.d/"${script}".cfg
    /opt/debian-cis/bin/hardening/"${script}".sh || true

    describe Checking resolved state
    register_test retvalshouldbe 0
    register_test contain "[ OK ] -a exit,always -F arch=b64 -S sethostname -S setdomainname -k system-locale is present in /etc/audit/rules.d/audit.rules"
    register_test contain "[ OK ] -a exit,always -F arch=b32 -S sethostname -S setdomainname -k system-locale is present in  /etc/audit/rules.d/audit.rules"
    register_test contain "[ OK ] -w /etc/issue -p wa -k system-locale is present in /etc/audit/rules.d/audit.rules"
    register_test contain "[ OK ] -w /etc/issue.net -p wa -k system-locale is present in /etc/audit/rules.d/audit.rules"
    register_test contain "[ OK ] -w /etc/hosts -p wa -k system-locale is present in /etc/audit/rules.d/audit.rules"
    register_test contain "[ OK ] -w /etc/network -p wa -k system-locale is present in /etc/audit/rules.d/audit.rules"
    run resolved /opt/debian-cis/bin/hardening/"${script}".sh --audit-all

}
