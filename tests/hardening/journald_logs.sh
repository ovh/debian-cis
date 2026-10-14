# shellcheck shell=bash
# run-shellcheck
test_audit() {
    local conf_dir="/etc/systemd/journald.conf.d"
    local conf_dropin="$conf_dir/99-forward-to-syslog.conf"

    describe Running on blank host
    register_test retvalshouldbe 0
    # shellcheck disable=2154
    run blank "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    describe Tests purposely failing
    mkdir -p "$conf_dir"
    printf '[Journal]\nForwardToSyslog=no\n' >"$conf_dropin"
    register_test retvalshouldbe 1
    register_test contain "effectively set to no in journald configuration"
    run noncompliant "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    describe correcting situation
    sed -i 's/audit/enabled/' "${CIS_CONF_DIR}/conf.d/${script}.cfg"
    "${CIS_CHECKS_DIR}/${script}.sh" --apply || true

    describe Checking resolved state
    register_test retvalshouldbe 0
    register_test contain "is not effectively set to no in journald configuration"
    run resolved "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    rm -f "$conf_dropin"
}
