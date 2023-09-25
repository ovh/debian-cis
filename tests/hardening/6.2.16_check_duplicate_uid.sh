# shellcheck shell=bash
# run-shellcheck
test_audit() {
    describe Running on blank host
    register_test retvalshouldbe 0
    register_test contain "[ OK ] No duplicate UIDs"
    # shellcheck disable=2154
    run blank "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    useradd -u 1001 usertest1
    useradd -o -u 1001 usertest2

    # Proceed to operation that will end up to a non compliant system
    describe Tests purposely failing
    register_test retvalshouldbe 1
    register_test contain "[ KO ] Duplicate UID (1001): usertest1 usertest2"
    run noncompliant "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    # shellcheck disable=2016
    echo 'EXCEPTIONS="$EXCEPTIONS 1001"' >>"${CIS_CONF_DIR}/conf.d/${script}.cfg"

    describe Adding exceptions
    register_test retvalshouldbe 0
    register_test contain "[ OK ] No duplicate UIDs apart from configured exceptions: (1001): usertest1 usertest2"
    run exception "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    # Cleanup
    userdel usertest1
    userdel usertest2
}
