# run-shellcheck
test_audit() {
    describe Running on blank host
    register_test retvalshouldbe 0
    dismiss_count_for_test
    # shellcheck disable=2154
    run blank /opt/debian-cis/bin/hardening/"${script}".sh --audit-all


    describe Creating failed state
    touch /var/log/auth.log
    touch /var/log/kern.log
    register_test retvalshouldbe 1
    run failing /opt/debian-cis/bin/hardening/"${script}".sh --audit-all

    describe Setting exceptions
    echo 'EXCEPTIONS=/var/log/auth.log:root:root:600' >> /opt/debian-cis/etc/conf.d/"${script}".cfg
    register_test retvalshouldbe 1
    run excepandfail /opt/debian-cis/bin/hardening/"${script}".sh --audit-all

    describe Correcting situation
    sed -i 's/audit/enabled/' /opt/debian-cis/etc/conf.d/"${script}".cfg
    /opt/debian-cis/bin/hardening/"${script}".sh || true

    register_test retvalshouldbe 0
    run resolved /opt/debian-cis/bin/hardening/"${script}".sh --audit-all
}
