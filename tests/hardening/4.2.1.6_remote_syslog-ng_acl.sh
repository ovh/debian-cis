# shellcheck shell=bash
# run-shellcheck
test_audit() {
    describe Running on blank host
    register_test retvalshouldbe 1
    # shellcheck disable=2154
    echo 'REMOTE_HOST="true"' >>"${CIS_CONF_DIR}/conf.d/${script}.cfg"
    run blank "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    cp -a /etc/syslog-ng/syslog-ng.conf /tmp/syslog-ng.conf.bak
    echo "source mySyslog tcp (\"127.0.0.1\")" >>/etc/syslog-ng/syslog-ng.conf

    describe Checking one line conf
    register_test retvalshouldbe 0
    run oneline "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    cp -a /tmp/syslog-ng.conf.bak /etc/syslog-ng/syslog-ng.conf
    cat >>/etc/syslog-ng/syslog-ng.conf <<EOF
    source mySyslog {
    tcp ("127.0.0.1"),
    port(1234),
EOF

    describe Checking mutliline conf
    register_test retvalshouldbe 0
    run multiline "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    mv /tmp/syslog-ng.conf.bak /etc/syslog-ng/syslog-ng.conf
    echo "source mySyslog tcp (\"127.0.0.1\")" >>/etc/syslog-ng/conf.d/1_tcp_source
    cat /etc/syslog-ng/conf.d/1_tcp_source

    describe Checking file in subdirectory
    register_test retvalshouldbe 0
    run subfile "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    rm -f /etc/syslog-ng/conf.d/1_tcp_source

}
