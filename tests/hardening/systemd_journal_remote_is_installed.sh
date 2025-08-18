# shellcheck shell=bash
# run-shellcheck
test_audit() {
    describe set up failed check
    apt remove -y systemd-journal-remote

    describe Running failed test
    register_test retvalshouldbe 1
    # shellcheck disable=2154
    run failure "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    describe Fix situation
    sed -i 's/audit/enabled/' "${CIS_CONF_DIR}/conf.d/${script}.cfg"
    "${CIS_CHECKS_DIR}/${script}.sh" --apply || true

    describe running successfull audit
    register_test retvalshouldbe 0
    # shellcheck disable=2154
    run success "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    apt remove -y systemd-journal-remote
    apt autoremove -y
}
