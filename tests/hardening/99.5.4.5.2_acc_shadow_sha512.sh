# shellcheck shell=bash
# run-shellcheck
test_audit() {
    describe Running on blank host
    register_test retvalshouldbe 0
    register_test contain "There is no password in /etc/shadow"
    dismiss_count_for_test
    # shellcheck disable=2154
    run blank /opt/debian-cis/bin/hardening/"${script}".sh --audit-all

    cp -a /etc/shadow /tmp/shadow.bak
    sed -i 's/secaudit:!/secaudit:mypassword/' /etc/shadow
    describe Fail: Found unsecure password
    register_test retvalshouldbe 1
    register_test contain "User secaudit has a password that is not SHA512 hashed"
    run unsecpasswd /opt/debian-cis/bin/hardening/"${script}".sh --audit-all

    sed -i 's/secaudit:mypassword/secaudit:!!/' /etc/shadow
    describe Fail: Found disabled password
    register_test retvalshouldbe 0
    register_test contain "User secaudit has a disabled password"
    run lockedpasswd /opt/debian-cis/bin/hardening/"${script}".sh --audit-all

    mv /tmp/shadow.bak /etc/shadow
    chpasswd -c SHA512 <<EOF
secaudit:mypassword
EOF
    describe Pass: Found properly hashed password
    register_test retvalshouldbe 0
    register_test contain "User secaudit has suitable SHA512 hashed password"
    run sha512pass /opt/debian-cis/bin/hardening/"${script}".sh --audit-all

    chpasswd -c SHA512 -s 1000 <<EOF
secaudit:mypassword
EOF
    describe Pass: Found properly hashed password with custom round number
    register_test retvalshouldbe 0
    register_test contain "User secaudit has suitable SHA512 hashed password"
    run sha512pass /opt/debian-cis/bin/hardening/"${script}".sh --audit-all
}
