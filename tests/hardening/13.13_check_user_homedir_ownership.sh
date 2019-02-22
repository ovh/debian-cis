# run-shellcheck
test_audit() {
    describe Running on blank host
    register_test retvalshouldbe 0
    # shellcheck disable=2154
    run blank /opt/debian-cis/bin/hardening/"${script}".sh --audit-all

    useradd -m testhomeuser
    chown root:root /home/testhomeuser

    describe Wrong home owner
    register_test retvalshouldbe 1
    run wronghomeowner /opt/debian-cis/bin/hardening/"${script}".sh --audit-all

    echo "EXCEPTIONS=\"/home/testhomeuser:testhomeuser:root\"" >> /opt/debian-cis/etc/conf.d/"${script}".cfg
    sed -i 's/audit/enabled/' /opt/debian-cis/etc/conf.d/"${script}".cfg

    describe Added exceptions
    register_test retvalshouldbe 0
    run exceptions /opt/debian-cis/bin/hardening/"${script}".sh --audit-all

    # Cleanup
    userdel testhomeuser
}
