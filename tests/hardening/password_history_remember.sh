# shellcheck shell=bash
# run-shellcheck
test_audit() {
    local pwhistory_profile="/usr/share/pam-configs/pwhistory"
    local pwhistory_backup="/tmp/pwhistory.backup.password_history_remember"
    local common_password_backup="/tmp/common-password.backup.password_history_remember"
    local cfg_backup="/tmp/password_history_remember.cfg.backup"
    # shellcheck disable=2154
    local cfg_file="${CIS_CONF_DIR}/conf.d/${script}.cfg"

    cp /etc/pam.d/common-password "$common_password_backup"
    if [ -f "$pwhistory_profile" ]; then
        cp "$pwhistory_profile" "$pwhistory_backup"
    fi

    # shellcheck disable=2154
    run create_config "${CIS_CHECKS_DIR}/${script}.sh" --create-config-files-only
    if [ -f "$cfg_file" ]; then
        cp "$cfg_file" "$cfg_backup"
    fi

    sed -i 's/^status=.*/status=audit/' "$cfg_file"
    if grep -q '^PWHR_MIN_REMEMBER=' "$cfg_file"; then
        sed -i 's/^PWHR_MIN_REMEMBER=.*/PWHR_MIN_REMEMBER=24/' "$cfg_file"
    else
        echo "PWHR_MIN_REMEMBER=24" >>"$cfg_file"
    fi

    describe Prepare non-compliant state with remember lower than policy
    {
        echo "Name: pwhistory password history checking"
        echo "Default: yes"
        echo "Priority: 1024"
        echo "Password-Type: Primary"
        echo "Password:"
        echo "   requisite pam_pwhistory.so remember=5 enforce_for_root try_first_pass use_authtok"
    } >"$pwhistory_profile"
    DEBIAN_FRONTEND='noninteractive' pam-auth-update --force --enable pwhistory

    describe Running non-compliant audit
    register_test retvalshouldbe 1
    register_test contain "lower than 24"
    # shellcheck disable=2154
    run noncompliant "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    describe Correcting situation
    sed -i 's/audit/enabled/' "${CIS_CONF_DIR}/conf.d/${script}.cfg"
    "${CIS_CHECKS_DIR}/${script}.sh" --apply || true

    describe Checking resolved state
    register_test retvalshouldbe 0
    register_test contain "is compliant"
    run resolved "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    describe Prepare non-compliant state with custom policy value
    sed -i 's/^status=.*/status=audit/' "$cfg_file"
    sed -i 's/^PWHR_MIN_REMEMBER=.*/PWHR_MIN_REMEMBER=10/' "$cfg_file"
    {
        echo "Name: pwhistory password history checking"
        echo "Default: yes"
        echo "Priority: 1024"
        echo "Password-Type: Primary"
        echo "Password:"
        echo "   requisite pam_pwhistory.so remember=5 enforce_for_root try_first_pass use_authtok"
    } >"$pwhistory_profile"
    DEBIAN_FRONTEND='noninteractive' pam-auth-update --force --enable pwhistory

    describe Running non-compliant audit with custom policy value
    register_test retvalshouldbe 1
    register_test contain "lower than 10"
    run noncompliant_custom_policy "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    describe Correcting situation with custom policy value
    sed -i 's/^status=.*/status=enabled/' "$cfg_file"
    "${CIS_CHECKS_DIR}/${script}.sh" --apply || true

    describe Checking resolved state with custom policy value
    register_test retvalshouldbe 0
    register_test contain "remember value 10 is compliant"
    run resolved_custom_policy "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    describe Restoring initial PAM configuration
    cp "$common_password_backup" /etc/pam.d/common-password

    if [ -f "$pwhistory_backup" ]; then
        cp "$pwhistory_backup" "$pwhistory_profile"
    else
        rm -f "$pwhistory_profile"
    fi

    DEBIAN_FRONTEND='noninteractive' pam-auth-update --force || true
    if [ -f "$cfg_backup" ]; then
        cp "$cfg_backup" "$cfg_file"
    fi
    rm -f "$pwhistory_backup" "$common_password_backup"
    rm -f "$cfg_backup"
}
