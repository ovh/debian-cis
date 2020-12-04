# shellcheck shell=bash
# run-shellcheck
test_audit() {
    describe Running on blank host
    register_test retvalshouldbe 0
    register_test contain "[ OK ] No account with uid 0 appart from root"
    # shellcheck disable=2154
    run blank /opt/debian-cis/bin/hardening/"${script}".sh --audit-all

    useradd -o -u 0 usertest1

    # Proceed to operation that will end up to a non compliant system
    describe Tests purposely failing
    register_test retvalshouldbe 1
    register_test contain "[ KO ] Some accounts have uid 0: usertest1"
    run noncompliant /opt/debian-cis/bin/hardening/"${script}".sh --audit-all

    # shellcheck disable=2016
    echo 'EXCEPTIONS="$EXCEPTIONS usertest1"' >>/opt/debian-cis/etc/conf.d/"${script}".cfg

    describe Adding exceptions
    register_test retvalshouldbe 0
    register_test contain "[ OK ] No account with uid 0 appart from root and configured exceptions: usertest1"
    run exception /opt/debian-cis/bin/hardening/"${script}".sh --audit-all

    # Cleanup
    userdel -f usertest1
}
