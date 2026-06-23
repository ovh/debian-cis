# shellcheck shell=bash
# run-shellcheck
test_audit() {
    describe Test without openssh-server installed
    apt-get purge -y openssh-server >/dev/null 2>&1 || true
    register_test retvalshouldbe 0
    register_test contain "not installed"
    # shellcheck disable=2154
    run no_ssh "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    describe Installing openssh-server for tests
    apt-get update >/dev/null 2>&1 || true
    apt-get install -y openssh-server >/dev/null 2>&1 || {
        skip "Cannot install openssh-server, skipping tests"
        return
    }

    describe Running on blank host
    register_test retvalshouldbe 0
    dismiss_count_for_test
    # shellcheck disable=2154
    run blank "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    describe Tests purposely failing
    # Enable GSSAPIAuthentication
    echo "GSSAPIAuthentication yes" >>/etc/ssh/sshd_config
    register_test retvalshouldbe 1
    register_test contain "not properly set"
    run noncompliant "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    describe Correcting situation
    sed -i 's/audit/enabled/' "${CIS_CONF_DIR}/conf.d/${script}.cfg"
    "${CIS_CHECKS_DIR}/${script}.sh" --apply || true

    describe Checking resolved state
    register_test retvalshouldbe 0
    register_test contain "is set to no"
    run resolved "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    # Cleanup
    sed -i '/^GSSAPIAuthentication/d' /etc/ssh/sshd_config
    apt-get purge -y openssh-server >/dev/null 2>&1 || true
}
