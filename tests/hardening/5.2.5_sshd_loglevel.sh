# run-shellcheck
test_audit() {
    describe Running on blank host
    register_test retvalshouldbe 1
    dismiss_count_for_test
    # shellcheck disable=2154
    run blank /opt/debian-cis/bin/hardening/"${script}".sh --audit-all

    describe Fix state
    sed -i 's/audit/enabled/' /opt/debian-cis/etc/conf.d/"${script}".cfg
    /opt/debian-cis/bin/hardening/"${script}".sh || true

    describe Checking resolved state
    register_test retvalshouldbe 0
    run resolved /opt/debian-cis/bin/hardening/"${script}".sh --audit-all

    echo "OPTIONS='LogLevel=DEBUG'" >> /opt/debian-cis/etc/conf.d/"${script}".cfg
    sed -i 's/LogLevel VERBOSE/LogLevel DEBUG/' /etc/ssh/sshd_config

    describe Checking custom conf
    register_test retvalshouldbe 0
    run customconf /opt/debian-cis/bin/hardening/"${script}".sh --audit-all
}
