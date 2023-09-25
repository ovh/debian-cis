# shellcheck shell=bash
# run-shellcheck
test_audit() {
    describe Running void to generate the conf file that will later be edited
    # shellcheck disable=2154
    "${CIS_CHECKS_DIR}/${script}.sh" || true
    # shellcheck disable=2016
    echo 'EXCEPTIONS="$EXCEPTIONS /usr/bin/dotlock.mailutils /usr/lib/x86_64-linux-gnu/utempter/utempter"' >>"${CIS_CONF_DIR}/conf.d/${script}.cfg"

    describe Running on blank host
    register_test retvalshouldbe 0
    dismiss_count_for_test
    # shellcheck disable=2154
    run blank "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    describe Tests purposely failing
    local targetfile="/home/secaudit/sgid_file"
    touch "$targetfile"
    chmod 2700 "$targetfile"
    register_test retvalshouldbe 1
    register_test contain "Some sgid files are present"
    register_test contain "$targetfile"
    run noncompliant "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    describe Tests failing with find ignore flag
    echo 'FIND_IGNORE_NOSUCHFILE_ERR=true' >>"${CIS_CONF_DIR}/conf.d/${script}.cfg"
    register_test retvalshouldbe 1
    register_test contain "Some sgid files are present"
    run noncompliant "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    describe correcting situation
    chmod 700 $targetfile

    describe Checking resolved state
    register_test retvalshouldbe 0
    register_test contain "No unknown sgid files found"
    run resolved "${CIS_CHECKS_DIR}/${script}.sh" --audit-all
}
