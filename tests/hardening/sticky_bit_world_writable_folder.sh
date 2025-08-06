# shellcheck shell=bash
# run-shellcheck
test_audit() {
    describe Running void to generate the conf file that will later be edited
    # shellcheck disable=2154
    "${CIS_CHECKS_DIR}/${script}.sh" || true
    # shellcheck disable=2016
    echo 'EXCEPTIONS="$EXCEPTIONS /home/secaudit/exception"' >>"${CIS_CONF_DIR}/conf.d/${script}.cfg"
    mkdir /home/secaudit/exception
    chmod 777 /home/secaudit/exception

    describe Running on blank host
    register_test retvalshouldbe 0
    register_test contain "All world writable directories have a sticky bit"
    # shellcheck disable=2154
    run blank "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    describe Tests purposely failing
    local targetdir="/home/secaudit/world_writable_folder"
    mkdir $targetdir || true
    chmod 777 "$targetdir"
    register_test retvalshouldbe 1
    register_test contain "Some world writable directories are not on sticky bit mode"
    run noncompliant "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    describe Tests failing with find ignore flag
    echo 'FIND_IGNORE_NOSUCHFILE_ERR=true' >>"${CIS_CONF_DIR}/conf.d/${script}.cfg"
    register_test retvalshouldbe 1
    register_test contain "Some world writable directories are not on sticky bit mode"
    run noncompliant "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    describe correcting situation
    sed -i 's/audit/enabled/' "${CIS_CONF_DIR}/conf.d/${script}.cfg"
    "${CIS_CHECKS_DIR}/${script}.sh" --apply || true

    describe Checking resolved state
    register_test retvalshouldbe 0
    register_test contain "All world writable directories have a sticky bit"
    run resolved "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

}
