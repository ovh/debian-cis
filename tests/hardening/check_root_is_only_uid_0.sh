# shellcheck shell=bash
# run-shellcheck
test_audit() {
    describe Running on blank host
    register_test retvalshouldbe 0
    dismiss_count_for_test
    # shellcheck disable=2154
    run blank "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    describe Tests purposely failing - creating UID 0 user
    useradd -o -u 0 testuid0user || true
    register_test retvalshouldbe 1
    register_test contain "have UID 0"
    run noncompliant "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    describe Correcting situation - script will not auto-fix
    sed -i 's/audit/enabled/' "${CIS_CONF_DIR}/conf.d/${script}.cfg"
    register_test retvalshouldbe 1
    register_test contain "Manual intervention required"
    run still_failing "${CIS_CHECKS_DIR}/${script}.sh" --apply || true

    describe Manual fix
    userdel testuid0user || true

    describe Checking resolved state
    register_test retvalshouldbe 0
    register_test contain "Only root account has UID 0"
    run resolved "${CIS_CHECKS_DIR}/${script}.sh" --audit-all
}
