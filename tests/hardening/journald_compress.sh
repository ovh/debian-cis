# shellcheck shell=bash
# run-shellcheck
test_audit() {
    describe Running on blank host
    register_test retvalshouldbe 0
    dismiss_count_for_test
    # shellcheck disable=2154
    run blank "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    local FILE="/etc/systemd/journald.conf"

    describe Tests purposely failing
    echo "Compress=no" >>"$FILE"
    register_test retvalshouldbe 1
    register_test contain "$FILE exists, checking configuration"
    register_test contain "is present in $FILE"
    run noncompliant "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    describe correcting situation
    sed -i 's/audit/enabled/' "${CIS_CONF_DIR}/conf.d/${script}.cfg"
    "${CIS_CHECKS_DIR}/${script}.sh" --apply || true

    describe Checking resolved state
    register_test retvalshouldbe 0
    register_test contain "is not present in $FILE"
    run resolved "${CIS_CHECKS_DIR}/${script}.sh" --audit-all
}
