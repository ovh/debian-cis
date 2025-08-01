# shellcheck shell=bash
# run-shellcheck
test_audit() {
    describe prepare test
    apt install systemd-journal-remote -y

    # by default authentication should not be configured
    describe Running failed
    register_test retvalshouldbe 1
    # shellcheck disable=2154
    run failed "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    describe Fix situation
    for i in "URL" "ServerKeyFile" "ServerCertificateFile" "TrustedCertificateFile"; do
        echo "$i=" >>/etc/systemd/journal-upload.conf
    done

    describe Running resolved
    register_test retvalshouldbe 0
    # shellcheck disable=2154
    run resolved "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    describe clean test
    apt purge systemd-journal-remote -y
    apt autoremove -y

}
