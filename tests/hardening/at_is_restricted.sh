# shellcheck shell=bash
# run-shellcheck
test_audit() {

    describe prepare test
    rm -f /etc/at.allow
    apt install -y at

    # at package is going to provide at.deny with default content
    describe Running on blank host
    register_test retvalshouldbe 0
    # shellcheck disable=2154
    run blank "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    describe Prepare failing test at.deny
    # wrong  perm
    chmod 0644 /etc/at.deny

    describe Running failed test at.deny
    register_test retvalshouldbe 1
    run failure "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    describe Correcting situation
    sed -i 's/audit/enabled/' "${CIS_CONF_DIR}/conf.d/${script}.cfg"
    "${CIS_CHECKS_DIR}/${script}.sh" || true

    describe Running success test at.deny
    register_test retvalshouldbe 0
    run success "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    describe Prepare failing test at.deny
    # empty file + at.allow inexistent = all users allowed
    # shellcheck disable=2188
    >/etc/at.deny

    describe Running failed test at.deny
    register_test retvalshouldbe 1
    run failure "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    describe Correcting situation
    "${CIS_CHECKS_DIR}/${script}.sh" || true

    describe Running success test at.deny
    register_test retvalshouldbe 0
    run success "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    describe Prepare failing test at.allow
    touch /etc/at.allow
    # wrong user
    chown secaudit:root /etc/at.allow

    describe Running failed test at.allow
    register_test retvalshouldbe 1
    run failure "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    describe Correcting situation
    "${CIS_CHECKS_DIR}/${script}.sh" || true

    describe Running success test at.allow
    register_test retvalshouldbe 0
    run success "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    describe cleanup at
    apt remove -y at
    apt autoremove -y
    rm -f /etc/allow

    describe Running success at package missing
    register_test retvalshouldbe 0
    run success "${CIS_CHECKS_DIR}/${script}.sh" --audit-all
}
