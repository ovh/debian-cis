# shellcheck shell=bash
# run-shellcheck
test_audit() {
    describe Running on blank host
    register_test retvalshouldbe 0
    dismiss_count_for_test
    # shellcheck disable=2154
    run blank "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    local test_user="testetcgroupuser"

    describe Tests purposely failing
    useradd "$test_user"
    sed -i "s/$test_user:x/+:$test_user:x/" /etc/group
    register_test retvalshouldbe 1
    register_test contain "Some accounts have a legacy group entry"
    run noncompliant "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    describe correcting situation
    sed -i 's/audit/enabled/' "${CIS_CONF_DIR}/conf.d/${script}.cfg"
    "${CIS_CHECKS_DIR}/${script}.sh" --apply || true

    describe Checking resolved state
    register_test retvalshouldbe 0
    register_test contain "All accounts have a valid group entry format"
    run resolved "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    # cleanup
    userdel "$test_user"
}
