# shellcheck shell=bash
# run-shellcheck
test_audit() {
    # shellcheck disable=2154
    echo 'EXCEPTION_USERS=""' >>"${CIS_CONF_DIR}/conf.d/${script}.cfg"

    skip_tests
    # shellcheck disable=2154
    run genconf "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    useradd -s /bin/bash jeantestuser
    describe Running on blank host
    register_test retvalshouldbe 0
    dismiss_count_for_test
    register_test contain "[INFO] User root has a valid shell"
    register_test contain "[WARN] secaudit has a valid shell but no authorized_keys file"
    register_test contain "[INFO] User jeantestuser has a valid shell"
    register_test contain "[INFO] User jeantestuser has no home directory"
    # shellcheck disable=2154
    run blank "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    mkdir -p /root/.ssh
    ssh-keygen -N "" -t ed25519 -f /tmp/rootkey1
    cat /tmp/rootkey1.pub >>/root/.ssh/authorized_keys
    describe Check /root is used for root user instead of home by placing key without from field
    register_test retvalshouldbe 1
    run rootcheck "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    echo 'EXCEPTION_USERS="root exceptiontestuser"' >>"${CIS_CONF_DIR}/conf.d/${script}.cfg"
    useradd -s /bin/bash exceptiontestuser
    describe Check multiple exception users are skipped
    register_test retvalshouldbe 0
    register_test contain "[INFO] User root is named in EXEPTION_USERS and is thus skipped from check."
    register_test contain "[INFO] User exceptiontestuser is named in EXEPTION_USERS and is thus skipped from check."
    # shellcheck disable=2154
    run exceptionusers "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    mkdir -p /home/secaudit/.ssh
    touch /home/secaudit/.ssh/authorized_keys2
    describe empty authorized keys file
    register_test retvalshouldbe 0
    run emptyauthkey "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    ssh-keygen -N "" -t ed25519 -f /tmp/key1
    cat /tmp/key1.pub >>/home/secaudit/.ssh/authorized_keys2
    describe Key without from field
    register_test retvalshouldbe 1
    run keynofrom "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    {
        echo -n 'from="127.0.0.1" '
        cat /tmp/key1.pub
    } >/home/secaudit/.ssh/authorized_keys2
    describe Key with from, no ip check
    register_test retvalshouldbe 0
    run keyfrom "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    # shellcheck disable=2016
    echo 'ALLOWED_IPS="$ALLOWED_IPS 127.0.0.1"' >>"${CIS_CONF_DIR}/conf.d/${script}.cfg"
    {
        echo -n 'from="10.0.1.2" '
        cat /tmp/key1.pub
    } >>/home/secaudit/.ssh/authorized_keys2
    describe Key with from, filled allowed IPs, one bad ip
    register_test retvalshouldbe 1
    run badfromip "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    # shellcheck disable=2016
    echo 'ALLOWED_IPS="$ALLOWED_IPS 10.0.1.2"' >>"${CIS_CONF_DIR}/conf.d/${script}.cfg"
    describe Key with from, filled allowed IPs, all IPs allowed
    register_test retvalshouldbe 0
    run allwdfromip "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    # shellcheck disable=2016
    echo 'ALLOWED_IPS="$ALLOWED_IPS 127.0.0.1,10.2.3.1/8"' >>"${CIS_CONF_DIR}/conf.d/${script}.cfg"
    {
        echo -n 'from="10.0.1.2",command="echo bla" '
        cat /tmp/key1.pub
        echo -n 'command="echo bla,from="10.0.1.2,10.2.3.1/8"" '
        cat /tmp/key1.pub
    } >>/home/secaudit/.ssh/authorized_keys2
    describe Key with from and command options
    register_test retvalshouldbe 0
    run keyfromcommand "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    useradd -s /bin/bash -m jeantest2
    # shellcheck disable=2016
    echo 'USERS_TO_CHECK="jeantest2 secaudit"' >>"${CIS_CONF_DIR}/conf.d/${script}.cfg"
    describe Check only specified user
    register_test retvalshouldbe 0
    run checkuser "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    # Cleanup
    userdel exceptiontestuser
    userdel jeantestuser
    userdel -r jeantest2
    rm -f /tmp/key1 /tmp/key1.pub /tmp/rootkey1.pub
    rm -rf /root/.ssh
}
