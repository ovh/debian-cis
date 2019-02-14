# run-shellcheck
test_audit()  {
    skip_tests
    # shellcheck disable=2154
    run genconf /opt/debian-cis/bin/hardening/"${script}".sh --audit-all

    useradd -s /bin/bash jeantestuser
    describe Running on blank host
    register_test retvalshouldbe 0
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

    ssh-keygen -t ed25519 -f /tmp/key1
    cat /tmp/key1.pub >> /home/secaudit/.ssh/authorized_keys2
    describe Key without from field
    register_test retvalshouldbe 1
    run keynofrom /opt/debian-cis/bin/hardening/"${script}".sh --audit-all

    echo -n 'from="127.0.0.1" ' > /home/secaudit/.ssh/authorized_keys2
    cat /tmp/key1.pub >> /home/secaudit/.ssh/authorized_keys2
    describe Key with from, no ip check
    register_test retvalshouldbe 0
    run keyfrom /opt/debian-cis/bin/hardening/"${script}".sh --audit-all

    # shellcheck disable=2016
    echo 'ALLOWED_IPS="$ALLOWED_IPS 127.0.0.1"' >>  /opt/debian-cis/etc/conf.d/"${script}".cfg
    echo -n 'from="10.0.1.2" ' >> /home/secaudit/.ssh/authorized_keys2
    cat /tmp/key1.pub >> /home/secaudit/.ssh/authorized_keys2
    describe Key with from, filled allowed IPs, one bad ip
    register_test retvalshouldbe 1
    run badfromip /opt/debian-cis/bin/hardening/"${script}".sh --audit-all

    # shellcheck disable=2016
    echo 'ALLOWED_IPS="$ALLOWED_IPS 10.0.1.2"' >>  /opt/debian-cis/etc/conf.d/"${script}".cfg
    describe Key with from, filled allowed IPs, all IPs allowed
    register_test retvalshouldbe 0
    run allwdfromip /opt/debian-cis/bin/hardening/"${script}".sh --audit-all

    userdel jeantestuser
}

