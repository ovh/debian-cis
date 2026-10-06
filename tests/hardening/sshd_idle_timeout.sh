# shellcheck shell=bash
# run-shellcheck
test_audit() {
    describe "Installing openssh-server for tests"
    apt-get update >/dev/null 2>&1 || true
    DEBIAN_FRONTEND='noninteractive' apt-get install -y openssh-server >/dev/null 2>&1 || {
        skip "Cannot install openssh-server, skipping tests"
        return
    }

    describe "Starting ssh service"
    service ssh start || systemctl start ssh || true

    # Backup sshd_config
    cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bak

    describe "Prepare non-compliant state - set ClientAliveInterval=0 and ClientAliveCountMax=0"
    sed -i '/^[[:space:]]*[Cc]lient[Aa]live[Ii]nterval[[:space:]]/d' /etc/ssh/sshd_config
    sed -i '/^[[:space:]]*[Cc]lient[Aa]live[Cc]ount[Mm]ax[[:space:]]/d' /etc/ssh/sshd_config
    echo "ClientAliveInterval 0" >>/etc/ssh/sshd_config
    echo "ClientAliveCountMax 0" >>/etc/ssh/sshd_config

    describe "Running on purpose failed test - ClientAliveInterval and CountMax are 0"
    register_test retvalshouldbe 1
    register_test contain "ClientAliveInterval is not set or is 0"
    register_test contain "ClientAliveCountMax is not set or is 0"
    # shellcheck disable=2154
    run failed "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    describe "Correcting situation - enabling remediation"
    sed -i 's/audit/enabled/' "${CIS_CONF_DIR}/conf.d/${script}.cfg"
    "${CIS_CHECKS_DIR}/${script}.sh" --apply || true

    describe "Checking resolved state - ClientAliveInterval and CountMax > 0"
    register_test retvalshouldbe 0
    register_test contain "ClientAliveInterval is set to"
    register_test contain "ClientAliveCountMax is set to"
    run resolved "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    describe "Restore original sshd_config"
    mv /etc/ssh/sshd_config.bak /etc/ssh/sshd_config

    describe "Clean test - stop sshd"
    pkill -9 sshd || true
    sleep 1
    apt-get remove -y openssh-server >/dev/null 2>&1 || true
    apt-get autoremove -y >/dev/null 2>&1 || true
}
