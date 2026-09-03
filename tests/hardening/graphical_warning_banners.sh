# shellcheck shell=bash
# run-shellcheck
test_audit() {
    gdm_pkg=""
    gdm_installed_before=0
    profile_backup=""
    dbdir_backup=""
    dbfile_backup=""
    test_profile="gdm"
    test_profile_file="/etc/dconf/profile/${test_profile}"
    test_db_dir="/etc/dconf/db/${test_profile}.d"
    test_db_file="/etc/dconf/db/${test_profile}"

    is_pkg_installed_for_test() {
        dpkg-query -W -f='${db:Status-Status}' "$1" 2>/dev/null | grep -Eqx 'installed|triggers-awaited|triggers-pending'
    }

    if is_pkg_installed_for_test gdm3; then
        gdm_pkg="gdm3"
        gdm_installed_before=1
    elif is_pkg_installed_for_test gdm; then
        gdm_pkg="gdm"
        gdm_installed_before=1
    else
        for candidate_pkg in gdm3 gdm; do
            DEBIAN_FRONTEND=noninteractive apt-get install -y "$candidate_pkg" >/dev/null 2>&1 || true
            if is_pkg_installed_for_test "$candidate_pkg"; then
                gdm_pkg="$candidate_pkg"
                break
            fi
        done

        if [ -z "$gdm_pkg" ]; then
            skip "Cannot install gdm/gdm3, skipping tests"
            return
        fi
    fi

    if [ -f "$test_profile_file" ]; then
        profile_backup=$(mktemp)
        cp "$test_profile_file" "$profile_backup"
    fi

    if [ -d "$test_db_dir" ]; then
        dbdir_backup=$(mktemp -d)
        cp -a "$test_db_dir" "$dbdir_backup/dbdir"
    fi

    if [ -f "$test_db_file" ]; then
        dbfile_backup=$(mktemp)
        cp "$test_db_file" "$dbfile_backup"
    fi

    rm -f "$test_profile_file"
    rm -rf "$test_db_dir"
    rm -f "$test_db_file"

    describe non compliant gdm login banner state
    register_test retvalshouldbe 1
    # shellcheck disable=2154
    run noncompliant "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    describe correcting situation
    # shellcheck disable=2154
    sed -i 's/audit/enabled/' "${CIS_CONF_DIR}/conf.d/${script}.cfg"
    # shellcheck disable=2154
    "${CIS_CHECKS_DIR}/${script}.sh" --apply || true

    describe compliant gdm login banner state
    register_test retvalshouldbe 0
    # shellcheck disable=2154
    run resolved "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    rm -f "$test_profile_file"
    if [ -n "$profile_backup" ]; then
        cp "$profile_backup" "$test_profile_file"
        rm -f "$profile_backup"
    fi

    rm -rf "$test_db_dir"
    if [ -n "$dbdir_backup" ] && [ -d "$dbdir_backup/dbdir" ]; then
        cp -a "$dbdir_backup/dbdir" "$test_db_dir"
        rm -rf "$dbdir_backup"
    fi

    rm -f "$test_db_file"
    if [ -n "$dbfile_backup" ]; then
        cp "$dbfile_backup" "$test_db_file"
        rm -f "$dbfile_backup"
    fi

    if [ "$gdm_installed_before" -eq 0 ]; then
        apt-get purge -y "$gdm_pkg" >/dev/null 2>&1 || true
        apt-get autoremove -y >/dev/null 2>&1 || true
    fi
}
