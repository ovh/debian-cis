# shellcheck shell=bash
# run-shellcheck
test_audit() {
    describe Running on blank host
    register_test retvalshouldbe 0
    dismiss_count_for_test
    # shellcheck disable=2154
    run blank "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    local test_user="testdotuser"
    local test_file=".test"

    describe Tests purposely failing
    useradd --create-home "$test_user"
    touch "/home/$test_user/$test_file"
    chmod o+rx "/home/$test_user"
    chmod 777 "/home/$test_user/$test_file"
    register_test retvalshouldbe 1
    register_test contain "Group Write permission set on FILE"
    register_test contain "Other Write permission set on FILE"
    run noncompliant "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    describe correcting situation
    sed -i 's/audit/enabled/' "${CIS_CONF_DIR}/conf.d/${script}.cfg"
    "${CIS_CHECKS_DIR}/${script}.sh" --apply || true

    describe Checking resolved state
    register_test retvalshouldbe 0
    register_test contain "Dot file permission in users directories are correct"
    run resolved "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    # cleanup
    userdel -r "$test_user"
}
