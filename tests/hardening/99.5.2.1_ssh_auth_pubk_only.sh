# shellcheck shell=bash
# run-shellcheck
test_audit() {
    describe Running on blank host
    register_test retvalshouldbe 1
    register_test contain "openssh-server is installed"
    # shellcheck disable=2154
    run blank /opt/debian-cis/bin/hardening/"${script}".sh --audit-all

    describe Correcting situation
    # `apply` performs a service reload after each change in the config file
    # the service needs to be started for the reload to succeed
    service ssh start
    # if the audit script provides "apply" option, enable and run it
    sed -i 's/audit/enabled/' /opt/debian-cis/etc/conf.d/"${script}".cfg
    /opt/debian-cis/bin/hardening/"${script}".sh || true

    describe Checking resolved state
    register_test retvalshouldbe 0
    register_test contain "[ OK ] ^PubkeyAuthentication[[:space:]]+yes is present in /etc/ssh/sshd_config"
    register_test contain "[ OK ] ^PasswordAuthentication[[:space:]]+no is present in /etc/ssh/sshd_config"
    register_test contain "[ OK ] ^KbdInteractiveAuthentication[[:space:]]+no is present in /etc/ssh/sshd_config"
    register_test contain "[ OK ] ^KerberosAuthentication[[:space:]]+no is present in /etc/ssh/sshd_config"
    register_test contain "[ OK ] ^ChallengeResponseAuthentication[[:space:]]+no is present in /etc/ssh/sshd_config"
    register_test contain "[ OK ] ^HostbasedAuthentication[[:space:]]+no is present in /etc/ssh/sshd_config"
    register_test contain "[ OK ] ^GSSAPIAuthentication[[:space:]]+no is present in /etc/ssh/sshd_config"
    register_test contain "[ OK ] ^GSSAPIKeyExchange[[:space:]]+no is present in /etc/ssh/sshd_config"
    run resolved /opt/debian-cis/bin/hardening/"${script}".sh --audit-all
}
