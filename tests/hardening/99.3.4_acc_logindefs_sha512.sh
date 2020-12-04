# shellcheck shell=bash
# run-shellcheck
test_audit() {
    describe Running on blank host
    register_test retvalshouldbe 0
    register_test contain "ENCRYPT_METHOD SHA512 is present in /etc/login.defs"
    # shellcheck disable=2154
    run blank /opt/debian-cis/bin/hardening/"${script}".sh --audit-all

    cp /etc/login.defs /tmp/login.defs.bak
    describe Line as comment
    sed -i 's/\(ENCRYPT_METHOD SHA512\)/# \1/' /etc/login.defs
    register_test retvalshouldbe 1
    register_test contain "SHA512 is not present"
    run commented /opt/debian-cis/bin/hardening/"${script}".sh --audit-all

    rm /etc/login.defs
    describe Fail: missing conf file
    register_test retvalshouldbe 1
    register_test contain "/etc/login.defs is not readable"
    run missconffile /opt/debian-cis/bin/hardening/"${script}".sh --audit-all

    cp /tmp/login.defs.bak /etc/login.defs
    sed -ir 's/ENCRYPT_METHOD[[:space:]]\+SHA512/ENCRYPT_METHOD MD5/' /etc/login.defs
    describe Fail: wrong hash function configuration
    register_test retvalshouldbe 1
    register_test contain "SHA512 is not present"
    run wrongconf /opt/debian-cis/bin/hardening/"${script}".sh --audit-all

    describe Correcting situation
    sed -i 's/disabled/enabled/' /opt/debian-cis/etc/conf.d/"${script}".cfg
    /opt/debian-cis/bin/hardening/"${script}".sh || true

    describe Checking resolved state
    mv /tmp/login.defs.bak /etc/login.defs
    register_test retvalshouldbe 0
    run sha512pass /opt/debian-cis/bin/hardening/"${script}".sh --audit-all
}
