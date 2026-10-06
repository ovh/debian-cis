# shellcheck shell=bash
# run-shellcheck
test_audit() {
    local sshd_config="/etc/ssh/sshd_config"
    local sshd_config_backup="/tmp/ssh_cry_mac.sshd_config.bak.$$"
    local shuffled_macs='MACs umac-64@openssh.com,umac-128-etm@openssh.com,hmac-sha2-512,hmac-sha2-256-etm@openssh.com,umac-128@openssh.com,hmac-sha2-512-etm@openssh.com,umac-64-etm@openssh.com,hmac-sha2-256'
    local missing_macs='MACs umac-64@openssh.com,umac-128-etm@openssh.com,hmac-sha2-512,hmac-sha2-256-etm@openssh.com,umac-128@openssh.com,hmac-sha2-512-etm@openssh.com,umac-64-etm@openssh.com'

    describe "Installing openssh-server for tests"
    apt-get update >/dev/null 2>&1 || true
    DEBIAN_FRONTEND='noninteractive' apt-get install -y openssh-server >/dev/null 2>&1 || {
        skip "Cannot install openssh-server, skipping tests"
        return
    }

    if [ -f "$sshd_config" ]; then
        cp "$sshd_config" "$sshd_config_backup"
    fi

    sed -i '/^[[:space:]]*MACs[[:space:]]/d' "$sshd_config"
    echo "$shuffled_macs" >>"$sshd_config"

    describe "Running compliant state with shuffled MAC order"
    register_test retvalshouldbe 0
    register_test contain "hmac-sha2-256 is present in /etc/ssh/sshd_config"
    # shellcheck disable=2154
    run shuffled_order "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    sed -i '/^[[:space:]]*MACs[[:space:]]/d' "$sshd_config"
    echo "$missing_macs" >>"$sshd_config"

    describe "Running non-compliant state with one MAC missing"
    register_test retvalshouldbe 1
    register_test contain "hmac-sha2-256 is not present in /etc/ssh/sshd_config"
    # shellcheck disable=2154
    run missing_mac "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    describe Correcting situation
    # `apply` performs a service reload after each change in the config file
    # the service needs to be started for the reload to succeed
    service ssh start
    # if the audit script provides "apply" option, enable and run it
    sed -i 's/audit/enabled/' "${CIS_CONF_DIR}/conf.d/${script}.cfg"
    "${CIS_CHECKS_DIR}/${script}.sh" || true

    describe Checking resolved state
    register_test retvalshouldbe 0
    register_test contain "hmac-sha2-256 is present in /etc/ssh/sshd_config"
    run resolved "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    describe Clean test
    pkill -9 sshd || true
    apt-get remove -y openssh-server >/dev/null 2>&1 || true
    apt-get autoremove -y >/dev/null 2>&1 || true

    if [ -f "$sshd_config_backup" ]; then
        mv "$sshd_config_backup" "$sshd_config"
    fi
}
