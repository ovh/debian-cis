# shellcheck shell=bash
# run-shellcheck
test_audit() {
    describe Running void to generate the conf file that will later be edited
    # shellcheck disable=2154
    "${CIS_CHECKS_DIR}/${script}.sh" || true
    # shellcheck disable=2016
    echo 'EXCEPTIONS="$EXCEPTIONS /usr/bin/dotlock.mailutils /usr/lib/dbus-1.0/dbus-daemon-launch-helper /usr/sbin/exim4 /bin/fusermount /usr/lib/eject/dmcrypt-get-device /usr/bin/pkexec /usr/lib/policykit-1/polkit-agent-helper-1"' >>"${CIS_CONF_DIR}/conf.d/${script}.cfg"

    describe Running on blank host
    register_test retvalshouldbe 0
    dismiss_count_for_test
    run blank "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    describe Tests purposely failing
    local targetfile_suid="/home/secaudit/suid_file"
    touch "$targetfile_suid"
    chmod 4700 "$targetfile_suid"
    register_test retvalshouldbe 1
    register_test contain "$targetfile_suid"
    run noncompliant "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    describe Tests failing with find ignore flag
    echo 'FIND_IGNORE_NOSUCHFILE_ERR=true' >>"${CIS_CONF_DIR}/conf.d/${script}.cfg"
    register_test retvalshouldbe 1
    run noncompliant "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    describe Tests purposely failing
    local targetfile_sgid="/home/secaudit/sgid_file"
    touch "$targetfile_sgid"
    chmod 2700 "$targetfile_sgid"
    register_test retvalshouldbe 1
    register_test contain "$targetfile_sgid"
    run noncompliant "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    describe Tests failing with find ignore flag
    echo 'FIND_IGNORE_NOSUCHFILE_ERR=true' >>"${CIS_CONF_DIR}/conf.d/${script}.cfg"
    register_test retvalshouldbe 1
    run noncompliant "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    describe correcting situation
    chmod 700 $targetfile_suid $targetfile_sgid

    describe Checking resolved state
    register_test retvalshouldbe 0
    run resolved "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    describe clean test
    rm -f $targetfile_suid $targetfile_sgid

}
