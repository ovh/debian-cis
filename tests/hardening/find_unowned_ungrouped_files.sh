# shellcheck shell=bash
# run-shellcheck
test_audit() {
    describe Running void to generate the conf file that will later be edited
    # shellcheck disable=2154
    "${CIS_CHECKS_DIR}/${script}.sh" || true

    sed -i '/^IGNORED_PATH/d' "${CIS_CONF_DIR}/conf.d/${script}.cfg"
    # shellcheck disable=2016
    echo 'IGNORED_PATH="^/proc|^/home/secaudit/6.1.12/.*"' >>"${CIS_CONF_DIR}/conf.d/${script}.cfg"

    mkdir -p /home/secaudit/6.1.12/
    touch /home/secaudit/6.1.12/test
    chown 1200:1200 /home/secaudit/6.1.12/test

    describe Running on blank host
    register_test retvalshouldbe 0
    register_test contain "No unowned or ungrouped files found"
    # shellcheck disable=2154
    run blank "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    describe Tests purposely failing with both unowned and ungrouped files
    local unowned_target="/home/secaudit/unowned_file"
    local ungrouped_target="/home/secaudit/ungrouped_file"
    touch "$unowned_target" "$ungrouped_target"
    chown 1200 "$unowned_target"
    chown 1200:1200 "$ungrouped_target"

    register_test retvalshouldbe 1
    register_test contain "Some files are unowned and/or ungrouped are present"
    run noncompliant "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    describe Validate IGNORE_PATH excludes targeted files
    rm -f "$unowned_target" "$ungrouped_target"
    local ignored_target="/home/secaudit/6.1.12/ignored_unowned"
    touch "$ignored_target"
    chown 1200 "$ignored_target"

    register_test retvalshouldbe 0
    register_test contain "No unowned or ungrouped files found"
    run ignored_path_applied "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    describe Tests failing with find ignore flag
    sed -i '/^FIND_IGNORE_NOSUCHFILE_ERR/d' "${CIS_CONF_DIR}/conf.d/${script}.cfg"
    echo 'FIND_IGNORE_NOSUCHFILE_ERR=true' >>"${CIS_CONF_DIR}/conf.d/${script}.cfg"

    local unowned_target_2="/home/secaudit/unowned_file_2"
    touch "$unowned_target_2"
    chown 1200 "$unowned_target_2"

    register_test retvalshouldbe 1
    register_test contain "Some files are unowned and/or ungrouped are present"
    run noncompliant_ignore_err "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    describe correcting situation
    sed -i '/^status/s/audit/enabled/' "${CIS_CONF_DIR}/conf.d/${script}.cfg"
    "${CIS_CHECKS_DIR}/${script}.sh" --apply || true

    describe Checking resolved state
    register_test retvalshouldbe 0
    register_test contain "No unowned or ungrouped files found"
    run resolved "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    rm -rf /home/secaudit/6.1.12/ /home/secaudit/unowned_file /home/secaudit/ungrouped_file /home/secaudit/unowned_file_2
}
