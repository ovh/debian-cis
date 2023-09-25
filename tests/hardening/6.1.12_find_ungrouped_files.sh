# shellcheck shell=bash
# run-shellcheck
test_audit() {
    describe Running void to generate the conf file that will later be edited
    # shellcheck disable=2154
    "${CIS_CHECKS_DIR}/${script}.sh" || true
    # shellcheck disable=2016
    echo 'EXCLUDED="$EXCLUDED ^/home/secaudit/6.1.12/.*"' >>"${CIS_CONF_DIR}/conf.d/${script}.cfg"
    mkdir /home/secaudit/6.1.12/
    touch /home/secaudit/6.1.12/test
    chown 1200:1200 /home/secaudit/6.1.12/test

    describe Running on blank host
    register_test retvalshouldbe 0
    register_test contain "No ungrouped files found"
    # shellcheck disable=2154
    run blank "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    describe Tests purposely failing
    local targetfile="/home/secaudit/ungrouped"
    touch "$targetfile"
    chown 1200:1200 "$targetfile"
    register_test retvalshouldbe 1
    register_test contain "Some ungrouped files are present"
    run noncompliant "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    describe Tests failing with find ignore flag
    echo 'FIND_IGNORE_NOSUCHFILE_ERR=true' >>"${CIS_CONF_DIR}/conf.d/${script}.cfg"
    register_test retvalshouldbe 1
    register_test contain "Some ungrouped files are present"
    run noncompliant "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    describe correcting situation
    sed -i 's/audit/enabled/' "${CIS_CONF_DIR}/conf.d/${script}.cfg"
    "${CIS_CHECKS_DIR}/${script}.sh" --apply || true

    describe Checking resolved state
    register_test retvalshouldbe 0
    register_test contain "No ungrouped files found"
    run resolved "${CIS_CHECKS_DIR}/${script}.sh" --audit-all
}
