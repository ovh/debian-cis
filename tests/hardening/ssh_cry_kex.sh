# shellcheck shell=bash
# run-shellcheck
test_audit() {
    local sshd_config="/etc/ssh/sshd_config"
    local sshd_config_backup="/tmp/ssh_cry_kex.sshd_config.bak.$$"
    local shuffled_kex='KexAlgorithms curve25519-sha256@libssh.org,diffie-hellman-group14-sha256,curve25519-sha256,ecdh-sha2-nistp384,diffie-hellman-group16-sha512,ecdh-sha2-nistp256,diffie-hellman-group-exchange-sha256,diffie-hellman-group18-sha512,ecdh-sha2-nistp521'
    local missing_kex='KexAlgorithms curve25519-sha256@libssh.org,diffie-hellman-group14-sha256,curve25519-sha256,ecdh-sha2-nistp384,diffie-hellman-group16-sha512,ecdh-sha2-nistp256,diffie-hellman-group-exchange-sha256,diffie-hellman-group18-sha512'

    describe "Installing openssh-server for tests"
    apt-get update >/dev/null 2>&1 || true
    DEBIAN_FRONTEND='noninteractive' apt-get install -y openssh-server >/dev/null 2>&1 || {
        skip "Cannot install openssh-server, skipping tests"
        return
    }

    if [ -f "$sshd_config" ]; then
        cp "$sshd_config" "$sshd_config_backup"
    fi

    sed -i '/^[[:space:]]*KexAlgorithms[[:space:]]/d' "$sshd_config"
    echo "$shuffled_kex" >>"$sshd_config"

    describe "Running compliant state with shuffled KEX order"
    register_test retvalshouldbe 0
    register_test contain "ecdh-sha2-nistp521 is present in /etc/ssh/sshd_config"
    # shellcheck disable=2154
    run shuffled_order "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    sed -i '/^[[:space:]]*KexAlgorithms[[:space:]]/d' "$sshd_config"
    echo "$missing_kex" >>"$sshd_config"

    describe "Running non-compliant state with one KEX missing"
    register_test retvalshouldbe 1
    register_test contain "ecdh-sha2-nistp521 is not present in /etc/ssh/sshd_config"
    # shellcheck disable=2154
    run missing_kex "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    describe Correcting situation
    # `apply` performs a service reload after each change in the config file
    # the service needs to be started for the reload to succeed
    service ssh start
    # if the audit script provides "apply" option, enable and run it
    sed -i 's/audit/enabled/' "${CIS_CONF_DIR}/conf.d/${script}.cfg"
    "${CIS_CHECKS_DIR}/${script}.sh" || true

    cp -a /etc/ssh/sshd_config /tmp/sshd_config.bak

    describe Change case of config line
    sed -i 's/\(KexAlgorithms\)/\U\1/' /etc/ssh/sshd_config
    register_test retvalshouldbe 0
    register_test contain "ecdh-sha2-nistp521 is present in /etc/ssh/sshd_config"
    run uppercase "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    mv /tmp/sshd_config.bak /etc/ssh/sshd_config
    describe Checking resolved state
    register_test retvalshouldbe 0
    register_test contain "ecdh-sha2-nistp521 is present in /etc/ssh/sshd_config"
    run resolved "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    describe Clean test
    pkill -9 sshd || true
    apt-get remove -y openssh-server >/dev/null 2>&1 || true
    apt-get autoremove -y >/dev/null 2>&1 || true

    if [ -f "$sshd_config_backup" ]; then
        mv "$sshd_config_backup" "$sshd_config"
    fi
}
