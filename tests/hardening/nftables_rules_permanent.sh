# shellcheck shell=bash
# run-shellcheck
test_audit() {
    describe prepare failing test
    rm -f /etc/nftables.conf
    touch /etc/nftables.conf
    touch /etc/nftables.rules

    describe Running failed 'missing include'
    register_test retvalshouldbe 1
    # shellcheck disable=2154
    run failed "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    describe Fixing first situation
    sed -i 's/audit/enabled/' "${CIS_CONF_DIR}/conf.d/${script}.cfg"
    "${CIS_CHECKS_DIR}/${script}.sh" || true

    # the 'include' part is fixed, but configuration is missing
    # this has to be fixed manually, so for now, sill a failing test
    describe Running failed 'missing basic chains'
    register_test retvalshouldbe 1
    run failed "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    describe Fixing final situation
    echo 'hook input' >/etc/nftables.rules
    echo 'hook output' >>/etc/nftables.rules
    echo 'hook forward' >>/etc/nftables.rules

    describe Running success
    register_test retvalshouldbe 0
    run failed "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    describe clean test
    rm -f /etc/nftables.conf /etc/nftables.rules

}
