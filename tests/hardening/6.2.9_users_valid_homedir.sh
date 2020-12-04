# shellcheck shell=bash
# run-shellcheck
test_audit() {
    describe Running void to generate the conf file that will later be edited
    # shellcheck disable=2154
    /opt/debian-cis/bin/hardening/"${script}".sh || true
    echo "EXCEPTIONS=\"/:systemd-coredump:root\"" >>/opt/debian-cis/etc/conf.d/"${script}".cfg

    describe Running on blank host
    register_test retvalshouldbe 0
    dismiss_count_for_test
    # shellcheck disable=2154
    run blank /opt/debian-cis/bin/hardening/"${script}".sh --audit-all

    local test_user="testhomeuser"

    describe Test purposely failing
    useradd -m "$test_user"
    chown root:root /home/"$test_user"
    register_test retvalshouldbe 1
    register_test contain "[ KO ] The home directory (/home/$test_user) of user testhomeuser is owned by root"
    run noncompliant /opt/debian-cis/bin/hardening/"${script}".sh --audit-all

    describe correcting situation
    echo "EXCEPTIONS=\"/:systemd-coredump:root /home/$test_user:$test_user:root\"" >/opt/debian-cis/etc/conf.d/"${script}".cfg

    describe Checking resolved state
    register_test retvalshouldbe 0
    run resolved /opt/debian-cis/bin/hardening/"${script}".sh --audit-all

    # Cleanup
    rm -rf "/home/${test_user:?}"
    userdel -r "$test_user"
}
