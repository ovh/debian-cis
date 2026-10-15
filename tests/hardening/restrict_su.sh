# shellcheck shell=bash
# run-shellcheck
test_audit() {
    local su_file="/etc/pam.d/su"
    local su_file_backup="/tmp/restrict_su.su.bak.$$"
    # shellcheck disable=2154
    local cfg_file="${CIS_CONF_DIR}/conf.d/${script}.cfg"

    if [ -f "$su_file" ]; then
        cp "$su_file" "$su_file_backup"
    fi

    cat <<EOF >"$cfg_file"
status=audit
SU_WHEEL_GROUP=''
EOF

    sed -i '/^SU_WHEEL_GROUP=/d' "$cfg_file"
    printf "%s\n" "SU_WHEEL_GROUP=''" >>"$cfg_file"

    sed -i '/^[[:space:]]*auth[[:space:]]\+required[[:space:]]\+pam_wheel\.so/d' "$su_file"

    describe "Case without pam_wheel.so"
    register_test retvalshouldbe 1
    register_test contain "^auth[[:space:]]*required[[:space:]]*pam_wheel\\.so$ is not present in /etc/pam.d/su"
    # shellcheck disable=2154
    run noncompliant "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    describe Correcting situation
    sed -i 's/audit/enabled/' "$cfg_file"
    "${CIS_CHECKS_DIR}/${script}.sh" || true

    describe Checking resolved state for case without pam_wheel.so
    register_test retvalshouldbe 0
    register_test contain "^auth[[:space:]]*required[[:space:]]*pam_wheel\\.so$ is present in /etc/pam.d/su"
    run resolved_without_pam_wheel "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    describe "Case with pam_wheel.so and no group configured"
    sed -i '/^[[:space:]]*auth[[:space:]]\+required[[:space:]]\+pam_wheel\.so/d' "$su_file"
    printf '%s\n' 'auth       required   pam_wheel.so' >>"$su_file"
    sed -i '/^SU_WHEEL_GROUP=/d' "$cfg_file"
    printf "%s\n" "SU_WHEEL_GROUP=''" >>"$cfg_file"

    register_test retvalshouldbe 0
    register_test contain "^auth[[:space:]]*required[[:space:]]*pam_wheel\\.so$ is present in /etc/pam.d/su"
    run no_group "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    describe Correcting no-group case
    sed -i 's/audit/enabled/' "$cfg_file"
    "${CIS_CHECKS_DIR}/${script}.sh" || true

    describe Checking resolved state for case with pam_wheel.so and no group configured
    register_test retvalshouldbe 0
    register_test contain "^auth[[:space:]]*required[[:space:]]*pam_wheel\\.so$ is present in /etc/pam.d/su"
    run resolved_no_group "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    sed -i '/^[[:space:]]*auth[[:space:]]\+required[[:space:]]\+pam_wheel\.so/d' "$su_file"
    printf '%s\n' 'auth       required   pam_wheel.so use_uid group=root' >>"$su_file"
    sed -i '/^SU_WHEEL_GROUP=/d' "$cfg_file"
    printf "%s\n" "SU_WHEEL_GROUP='root'" >>"$cfg_file"

    describe "Case with pam_wheel.so and group configured"
    register_test retvalshouldbe 0
    register_test contain "^auth[[:space:]]*required[[:space:]]*pam_wheel\\.so[[:space:]]+use_uid[[:space:]]+group=root$ is present in /etc/pam.d/su"
    run with_group "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    describe Correcting group case
    sed -i 's/audit/enabled/' "$cfg_file"
    "${CIS_CHECKS_DIR}/${script}.sh" || true

    describe Checking resolved state for case with pam_wheel.so and group configured
    register_test retvalshouldbe 0
    register_test contain "^auth[[:space:]]*required[[:space:]]*pam_wheel\\.so[[:space:]]+use_uid[[:space:]]+group=root$ is present in /etc/pam.d/su"
    run resolved_with_group "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    if [ -f "$su_file_backup" ]; then
        mv "$su_file_backup" "$su_file"
    fi

}
