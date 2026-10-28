# shellcheck shell=bash
# run-shellcheck
test_audit() {
    local override='/etc/tmpfiles.d/systemd.conf'
    local backup='/tmp/tmpfiles-systemd.conf.bak'
    # shellcheck disable=2154
    local cfg_file="${CIS_CONF_DIR}/conf.d/${script}.cfg"

    if [ -f "$override" ]; then
        cp "$override" "$backup"
    fi
    mkdir -p /etc/tmpfiles.d

    describe Running on default configuration
    rm -f "$override"
    # result depends on the systemd version shipped by the distribution
    dismiss_count_for_test
    register_test contain "/usr/lib/tmpfiles.d/systemd.conf"
    # shellcheck disable=2154
    run default "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    describe Prepare on purpose failed test: journal file too permissive
    printf '%s\n' 'z /var/log/journal/%m/system.journal 0644 root systemd-journal - -' >"$override"
    register_test retvalshouldbe 1
    register_test contain "is more permissive than 0640 in $override"
    run file_too_open "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    describe Prepare on purpose failed test: recursive mode without mask applied to journal files
    printf '%s\n' 'Z /run/log/journal/%m 2750 root systemd-journal - -' >"$override"
    register_test retvalshouldbe 1
    register_test contain "is more permissive than 0640 in $override"
    run recursive_unmasked "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    describe Correcting situation manually
    {
        # more restrictive than 0640 is compliant
        printf '%s\n' 'z /var/log/journal/%m/system.journal 0600 root systemd-journal - -'
        # '~' removes the executable and special bits on journal files: 0640
        printf '%s\n' 'Z /run/log/journal/%m ~2750 root systemd-journal - -'
        # directories are not checked by default
        printf '%s\n' 'z /var/log/journal 2755 root systemd-journal - -'
        # ACL lines do not set a mode
        printf '%s\n' 'a+ /var/log/journal - - - - group:adm:r-x'
        # non journal paths are out of scope
        printf '%s\n' 'd /run/user 0755 root root -'
    } >"$override"

    describe Checking resolved state
    register_test retvalshouldbe 0
    register_test contain "journal files permissions are 0640 or more restrictive in $override"
    run resolved "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    describe Prepare on purpose failed test: journal directory too permissive for site policy
    sed -i 's/^JOURNALD_FOLDER_PERMS=.*/JOURNALD_FOLDER_PERMS=0750/' "$cfg_file"
    register_test retvalshouldbe 1
    register_test contain "is more permissive than 0750 in $override"
    run folder_too_open "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    describe Correcting situation manually
    sed -i 's|^z /var/log/journal 2755|z /var/log/journal 2750|' "$override"

    describe Checking resolved state
    register_test retvalshouldbe 0
    run resolved_folder "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    describe clean test
    sed -i 's/^JOURNALD_FOLDER_PERMS=.*/JOURNALD_FOLDER_PERMS=""/' "$cfg_file"
    rm -f "$override"
    if [ -f "$backup" ]; then
        mv "$backup" "$override"
    fi

}
