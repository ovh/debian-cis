# shellcheck shell=bash
# run-shellcheck
test_audit() {
    # shellcheck disable=2154
    echo 'EXCEPTION_USER="root"' >>/opt/debian-cis/etc/conf.d/"${script}".cfg

    skip_tests
    # shellcheck disable=2154
    run genconf /opt/debian-cis/bin/hardening/"${script}".sh --audit-all

    useradd -s /bin/bash jeantestuser
    describe Running on blank host
    register_test retvalshouldbe 0
    dismiss_count_for_test
    register_test contain "[WARN] secaudit has a valid shell but no authorized_keys file"
    register_test contain "[INFO] User jeantestuser has a valid shell"
    register_test contain "[INFO] User jeantestuser has no home directory"
    # shellcheck disable=2154
    run blank /opt/debian-cis/bin/hardening/"${script}".sh --audit-all

    mkdir -p /home/secaudit/.ssh
    touch /home/secaudit/.ssh/authorized_keys2
    describe empty authorized keys file
    register_test retvalshouldbe 0
    run emptyauthkey /opt/debian-cis/bin/hardening/"${script}".sh --audit-all

    ssh-keygen -N "" -t ed25519 -f /tmp/key1
    cat /tmp/key1.pub >>/home/secaudit/.ssh/authorized_keys2
    describe Key without from field
    register_test retvalshouldbe 1
    run keynofrom /opt/debian-cis/bin/hardening/"${script}".sh --audit-all

    {
        echo -n 'from="127.0.0.1" '
        cat /tmp/key1.pub
    } >/home/secaudit/.ssh/authorized_keys2
    describe Key with from, no ip check
    register_test retvalshouldbe 0
    run keyfrom /opt/debian-cis/bin/hardening/"${script}".sh --audit-all

    # shellcheck disable=2016
    echo 'ALLOWED_IPS="$ALLOWED_IPS 127.0.0.1"' >>/opt/debian-cis/etc/conf.d/"${script}".cfg
    {
        echo -n 'from="10.0.1.2" '
        cat /tmp/key1.pub
    } >>/home/secaudit/.ssh/authorized_keys2
    describe Key with from, filled allowed IPs, one bad ip
    register_test retvalshouldbe 1
    run badfromip /opt/debian-cis/bin/hardening/"${script}".sh --audit-all

    # shellcheck disable=2016
    echo 'ALLOWED_IPS="$ALLOWED_IPS 10.0.1.2"' >>/opt/debian-cis/etc/conf.d/"${script}".cfg
    describe Key with from, filled allowed IPs, all IPs allowed
    register_test retvalshouldbe 0
    run allwdfromip /opt/debian-cis/bin/hardening/"${script}".sh --audit-all

    # shellcheck disable=2016
    echo 'ALLOWED_IPS="$ALLOWED_IPS 127.0.0.1,10.2.3.1"' >>/opt/debian-cis/etc/conf.d/"${script}".cfg
    {
        echo -n 'from="10.0.1.2",command="echo bla" '
        cat /tmp/key1.pub
        echo -n 'command="echo bla,from="10.0.1.2,10.2.3.1"" '
        cat /tmp/key1.pub
    } >>/home/secaudit/.ssh/authorized_keys2
    describe Key with from and command options
    register_test retvalshouldbe 0
    run keyfromcommand /opt/debian-cis/bin/hardening/"${script}".sh --audit-all

    useradd -s /bin/bash -m jeantest2
    # shellcheck disable=2016
    echo 'USERS_TO_CHECK="jeantest2 secaudit"' >>/opt/debian-cis/etc/conf.d/"${script}".cfg
    describe Check only specified user
    register_test retvalshouldbe 0
    run checkuser /opt/debian-cis/bin/hardening/"${script}".sh --audit-all

    # Cleanup
    userdel jeantestuser
    userdel -r jeantest2
    rm -f /tmp/key1 /tmp/key1.pub
}
