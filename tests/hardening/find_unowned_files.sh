# shellcheck shell=bash
# run-shellcheck
test_audit() {
    describe Running void to generate the conf file that will later be edited
    # shellcheck disable=2154
    "${CIS_CHECKS_DIR}/${script}.sh" || true
    sed -i '/^EXCLUDED/d' "${CIS_CONF_DIR}/conf.d/${script}.cfg"
    # shellcheck disable=2016
    echo 'EXCLUDED="/proc|^/home/secaudit/6.1.11/.*"' >>"${CIS_CONF_DIR}/conf.d/${script}.cfg"
    mkdir /home/secaudit/6.1.11/
    touch /home/secaudit/6.1.11/test
    chown 1200 /home/secaudit/6.1.11/test

    describe Running on blank host
    register_test retvalshouldbe 0
    register_test contain "No unowned files found"
    # shellcheck disable=2154
    run blank "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    describe Tests purposely failing
    local targetfile="/home/secaudit/unowned"
    touch "$targetfile"
    chown 1200 "$targetfile"
    register_test retvalshouldbe 1
    register_test contain "Some unowned files are present"
    run noncompliant "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    describe Tests failing with find ignore flag
    sed -i '/^FIND_IGNORE_NOSUCHFILE_ERR/d' "${CIS_CONF_DIR}/conf.d/${script}.cfg"
    echo 'FIND_IGNORE_NOSUCHFILE_ERR=true' >>"${CIS_CONF_DIR}/conf.d/${script}.cfg"
    register_test retvalshouldbe 1
    register_test contain "Some unowned files are present"
    run noncompliant "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    describe correcting situation
    sed -i '/^status/s/audit/enabled/' "${CIS_CONF_DIR}/conf.d/${script}.cfg"
    "${CIS_CHECKS_DIR}/${script}.sh" || true

    describe Checking resolved state
    register_test retvalshouldbe 0
    register_test contain "No unowned files found"
    run resolved "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    rm -rf /home/secaudit/6.1.11 /home/secaudit/unowned
}
