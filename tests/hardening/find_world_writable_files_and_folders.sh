# shellcheck shell=bash
# run-shellcheck
test_audit() {
    describe Running void to generate the conf file that will later be edited
    # shellcheck disable=2154
    "${CIS_CHECKS_DIR}/${script}.sh" || true
    # shellcheck disable=2016
    echo 'EXCLUDED="$EXCLUDED ^/home/secaudit/thispathisignored.*|^/dev/.*"' >>"${CIS_CONF_DIR}/conf.d/${script}.cfg"
    touch /home/secaudit/thispathisignored
    chmod 777 /home/secaudit/thispathisignored
    mkdir -p /home/secaudit/thispathisignored_dir
    chmod 777 /home/secaudit/thispathisignored_dir

    describe Running on blank host
    register_test retvalshouldbe 0
    register_test contain "No world writable files or directories requiring remediation found"
    # shellcheck disable=2154
    run blank "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    describe Tests purposely failing with world writable file and directory
    local targetfile="/home/secaudit/worldwritable_file"
    local targetdir="/home/secaudit/worldwritable_dir"
    touch "$targetfile"
    mkdir -p "$targetdir"
    chmod 777 "$targetfile" "$targetdir"
    register_test retvalshouldbe 1
    register_test contain "Some world writable files or directories are present"
    run noncompliant "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    describe Tests failing with find ignore flag
    echo 'FIND_IGNORE_NOSUCHFILE_ERR=true' >>"${CIS_CONF_DIR}/conf.d/${script}.cfg"
    register_test retvalshouldbe 1
    register_test contain "Some world writable files or directories are present"
    run noncompliant_ignore_err "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    describe correcting situation
    sed -i 's/audit/enabled/' "${CIS_CONF_DIR}/conf.d/${script}.cfg"
    "${CIS_CHECKS_DIR}/${script}.sh" --apply || true

    describe Checking resolved state
    register_test retvalshouldbe 0
    register_test contain "No world writable files or directories requiring remediation found"
    run resolved "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    rm -rf /home/secaudit/thispathisignored /home/secaudit/thispathisignored_dir /home/secaudit/worldwritable_file /home/secaudit/worldwritable_dir
}
