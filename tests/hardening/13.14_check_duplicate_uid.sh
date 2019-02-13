# run-shellcheck
test_audit() {
    describe Running on blank host
    register_test retvalshouldbe 0
    register_test contain "[ OK ] No duplicate UIDs"
    # shellcheck disable=2154
    run blank /opt/debian-cis/bin/hardening/"${script}".sh --audit-all

    useradd usertest1
    useradd usertest2
    sed -i 's/1001/1000/g' /etc/passwd

    # Proceed to operation that will end up to a non compliant system
    describe Tests purposely failing
    register_test retvalshouldbe 1
    register_test contain "[ KO ] Duplicate UID (1000): usertest1 usertest2"
    run noncompliant /opt/debian-cis/bin/hardening/"${script}".sh --audit-all

    # shellcheck disable=2016
    echo 'EXCEPTIONS="$EXCEPTIONS 1000"' >> /opt/debian-cis/etc/conf.d/"${script}".cfg

    describe Adding exceptions
    register_test retvalshouldbe 0
    register_test contain "[ OK ] No duplicate UIDs apart from configured exceptions: (1000): usertest1 usertest2"
    run exception /opt/debian-cis/bin/hardening/"${script}".sh --audit-all

    # Cleanup
    userdel usertest1
    userdel usertest2
    sed -i '/usertest1/d' /etc/group
    sed -i '/usertest2/d' /etc/group
}

