# shellcheck shell=bash
# run-shellcheck
test_audit() {

    describe prepare failing test
    apt install -y chrony
    echo "user root" >>/etc/chrony/chrony.conf
    /usr/sbin/chronyd -Ux

    describe On purpose failing test
    register_test retvalshouldbe 1
    # shellcheck disable=2154
    run failed "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    describe correcting situation
    sed -i 's/audit/enabled/' "${CIS_CONF_DIR}/conf.d/${script}.cfg"
    "${CIS_CHECKS_DIR}/${script}.sh" --apply || true

    pkill chronyd
    /usr/sbin/chronyd -Ux

    describe resolved test
    register_test retvalshouldbe 0
    run failed "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    pkill chronyd
    apt remove chrony -y

}
