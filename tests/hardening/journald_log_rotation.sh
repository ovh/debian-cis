# shellcheck shell=bash
# run-shellcheck
test_audit() {
    local params_full="SystemMaxUse SystemKeepFree RuntimeMaxUse RuntimeKeepFree MaxFileSec"
    local params_short="SystemMaxUse SystemKeepFree RuntimeMaxUse"

    describe prepare failing test
    if [ -e /etc/systemd/journald.conf ]; then
        for param in $params_full; do
            sed -i "/$param/d" /etc/systemd/journald.conf
        done
    fi

    for param in $params_short; do
        echo "$param=" >>/etc/systemd/journald.conf
    done

    describe Checking failed test
    register_test retvalshouldbe 1
    # shellcheck disable=2154
    run failed "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    describe Fix test
    for param in $params_full; do
        echo "$param=" >>/etc/systemd/journald.conf
    done

    describe Checking failed test
    register_test retvalshouldbe 0
    # shellcheck disable=2154
    run failed "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

}
