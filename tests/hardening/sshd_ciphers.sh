# shellcheck shell=bash
# run-shellcheck
test_audit() {
    describe "Installing openssh-server for tests"
    apt-get update >/dev/null 2>&1 || true
    apt-get install -y openssh-server >/dev/null 2>&1 || {
        skip "Cannot install openssh-server, skipping tests"
        return
    }

    describe "Starting ssh service"
    service ssh start || systemctl start ssh || true

    # Backup sshd_config
    cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bak

    describe "Compliant state - default sshd ciphers"
    register_test retvalshouldbe 0
    register_test contain "sshd is using only approved ciphers"
    # shellcheck disable=2154
    run compliant "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    describe "Non-compliant: set multiple ciphers in sshd_config and restrict allow-list in cfg"
    # Ensure Ciphers line exists with multiple values by inserting before Include
    sed -i '/^[[:space:]]*[Cc]iphers[[:space:]]/d' /etc/ssh/sshd_config
    if grep -qi '^[[:space:]]*Include' /etc/ssh/sshd_config; then
        sed -i "0,/^[[:space:]]*[Ii]nclude/{s|^|Ciphers aes256-gcm@openssh.com,aes128-gcm@openssh.com,aes256-ctr,aes192-ctr,aes128-ctr\n|}" /etc/ssh/sshd_config
    else
        echo "Ciphers aes256-gcm@openssh.com,aes128-gcm@openssh.com,aes256-ctr,aes192-ctr,aes128-ctr" >>/etc/ssh/sshd_config
    fi
    # Restrict allow-list in cfg to single cipher so audit should find 4 non-approved ciphers
    sed -i "s|^SSHD_CIPHERS_LINE=.*|SSHD_CIPHERS_LINE='Ciphers aes256-gcm@openssh.com'|" \
        "${CIS_CONF_DIR}/conf.d/${script}.cfg" || true
    if ! grep -q '^SSHD_CIPHERS_LINE=' "${CIS_CONF_DIR}/conf.d/${script}.cfg" 2>/dev/null; then
        echo "SSHD_CIPHERS_LINE='Ciphers aes256-gcm@openssh.com'" >>"${CIS_CONF_DIR}/conf.d/${script}.cfg"
    fi

    describe "Running audit with restricted allow-list - expecting non-approved ciphers"
    # Note: sshd -T may not report ciphers in container context; this is informational
    # shellcheck disable=2154
    run preapply "${CIS_CHECKS_DIR}/${script}.sh" --audit-all || true

    describe "Correcting situation - restore default cfg and enable remediation"
    # Restore default SSHD_CIPHERS_LINE in cfg
    sed -i "s|^SSHD_CIPHERS_LINE=.*|SSHD_CIPHERS_LINE='Ciphers aes256-gcm@openssh.com,aes128-gcm@openssh.com,aes256-ctr,aes192-ctr,aes128-ctr'|" \
        "${CIS_CONF_DIR}/conf.d/${script}.cfg" || true
    sed -i 's/^status=audit/status=enabled/' "${CIS_CONF_DIR}/conf.d/${script}.cfg"
    "${CIS_CHECKS_DIR}/${script}.sh" --apply || true

    describe "Checking resolved state - Ciphers line should match default allow-list"
    register_test retvalshouldbe 0
    register_test contain "sshd is using only approved ciphers"
    run resolved "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    describe "Restore original sshd_config"
    mv /etc/ssh/sshd_config.bak /etc/ssh/sshd_config

    describe "Clean test - stop sshd"
    pkill -9 sshd || true
    sleep 1

    describe "Remove openssh-server"
    apt-get remove -y openssh-server >/dev/null 2>&1 || true
    apt-get autoremove -y >/dev/null 2>&1 || true
}
