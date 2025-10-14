# shellcheck shell=bash
# run-shellcheck
test_audit() {
    describe set up failing test for folders
    echo "d /run/systemd/seats 0755 root root -" >/etc/tmpfiles.d/systemd.conf

    describe Running failed test
    register_test retvalshouldbe 1
    # shellcheck disable=2154
    run failed "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    describe fix test
    echo "d /run/systemd/seats 0750 root root -" >/etc/tmpfiles.d/systemd.conf

    describe Running successful test
    register_test retvalshouldbe 0
    # shellcheck disable=2154
    run successful "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    describe set up failing test for files
    echo "f+! /run/utmp 0664 root utmp -" >/etc/tmpfiles.d/systemd.conf

    describe Running failed test
    register_test retvalshouldbe 1
    # shellcheck disable=2154
    run failed "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    describe fix test
    echo "f+! /run/utmp 0640 root utmp -" >/etc/tmpfiles.d/systemd.conf

    describe Running successful test
    register_test retvalshouldbe 0
    # shellcheck disable=2154
    run successful "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    describe clean test
    rm -f /etc/tmpfiles.d/systemd.conf

}
