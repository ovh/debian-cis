# shellcheck shell=bash
# run-shellcheck
test_audit() {
    local no_home_test_user="userwithouthome"
    local owner_test_user="testhomeuser"
    local perm_test_user="testhomepermuser"

    describe Running on blank host
    register_test retvalshouldbe 0
    # shellcheck disable=2154
    run blank "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    home_dir_missing "$no_home_test_user"
    home_dir_ownership "$owner_test_user"
    home_dir_perm "$perm_test_user"

    fix_home "$no_home_test_user" "$owner_test_user" "$perm_test_user"

    describe Checking resolved state
    register_test retvalshouldbe 0
    run resolved "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    cleanup "$no_home_test_user" "$owner_test_user" "$perm_test_user"
}

home_dir_missing() {
    local test_user="$1"

    useradd -d /home/"$test_user" "$test_user"
    describe Tests purposely failing that a homdedir does not exists
    register_test retvalshouldbe 1
    register_test contain "does not exist."
    run noncompliant "${CIS_CHECKS_DIR}/${script}.sh" --audit-all
}

home_dir_ownership() {
    local test_user="$1"

    describe Test purposely failing that a user does not own its home
    useradd -d /home/"$test_user" -m "$test_user"
    chown root:root /home/"$test_user"
    chmod 0750 /home/"$test_user"
    register_test retvalshouldbe 1
    register_test contain "[ KO ] The home directory (/home/$test_user) of user $test_user is owned by root"
    run noncompliant "${CIS_CHECKS_DIR}/${script}.sh" --audit-all
}

home_dir_perm() {
    local test_user="$1"

    describe Tests purposely failing for wrong permissions on home
    useradd -d /home/"$test_user" --create-home "$test_user"
    chmod 777 /home/"$test_user"
    register_test retvalshouldbe 1
    register_test contain "Group Write permission set on directory"
    register_test contain "Other Read permission set on directory"
    register_test contain "Other Write permission set on directory"
    register_test contain "Other Execute permission set on directory"

    run noncompliant "${CIS_CHECKS_DIR}/${script}.sh" --audit-all
}

fix_home() {
    local missing_home_test_user="$1"
    local owner_test_user="$2"
    local perm_test_user="$3"

    describe correcting situation for missing home
    install -d -m 0750 -o "$missing_home_test_user" /home/"$missing_home_test_user"

    describe correcting situation for ownership
    # we don't want to erase default configurations, or others checks could fail
    # shellcheck disable=2086
    sed -i '/^HOME_OWNER_EXCEPTIONS/s|HOME_OWNER_EXCEPTIONS=\"|HOME_OWNER_EXCEPTIONS=\"/home/'$owner_test_user':'$owner_test_user':root |' ${CIS_CONF_DIR}/conf.d/${script}.cfg

    describe correcting situation for permissions
    chmod 0750 /home/"$perm_test_user"

}

cleanup() {
    local users="$*"
    for user in $users; do
        # owner_test_user del will fail as its home is owned by another user
        userdel -r "$user" || true
        rm -rf /home/"${user:?}" || true
    done
}
