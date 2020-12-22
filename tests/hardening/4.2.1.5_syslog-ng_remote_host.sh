# shellcheck shell=bash
# run-shellcheck
test_audit() {

    describe Running on blank host
    register_test retvalshouldbe 1
    # shellcheck disable=2154
    run blank /opt/debian-cis/bin/hardening/"${script}".sh --audit-all

    cp -a /etc/syslog-ng/syslog-ng.conf /tmp/syslog-ng.conf.bak

    echo "destination mySyslog tcp (\"syslog.example.tld\")" >>/etc/syslog-ng/syslog-ng.conf
    grep syslog.example.tld /etc/syslog-ng/syslog-ng.conf

    describe Checking one line conf
    register_test retvalshouldbe 0
    run oneline /opt/debian-cis/bin/hardening/"${script}".sh --audit-all

    cp -a /tmp/syslog-ng.conf.bak /etc/syslog-ng/syslog-ng.conf
    cat >>/etc/syslog-ng/syslog-ng.conf <<EOF
destination mySyslog {
    tcp ("syslog.example.tld"),
    port(1234),
EOF

    describe Checking mutliline conf
    register_test retvalshouldbe 0
    run multiline /opt/debian-cis/bin/hardening/"${script}".sh --audit-all

    mv /tmp/syslog-ng.conf.bak /etc/syslog-ng/syslog-ng.conf

    #echo "#Sample conf" >/etc/syslog-ng/conf.d/1_tcp_destination
    echo "destination mySyslog tcp (\"syslog.example.tld\")" >>/etc/syslog-ng/conf.d/1_tcp_destination
    cat /etc/syslog-ng/conf.d/1_tcp_destination

    describe Checking file in subdirectory
    register_test retvalshouldbe 0
    run subfile /opt/debian-cis/bin/hardening/"${script}".sh --audit-all

    # Cleanup
    rm /etc/syslog-ng/conf.d/1_tcp_destination

}
