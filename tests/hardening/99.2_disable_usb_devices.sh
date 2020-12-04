# shellcheck shell=bash
# run-shellcheck
test_audit() {
    if [ -f "/.dockerenv" ]; then
        skip "SKIPPED on docker"
    else
        mkdir /etc/udev/rules.d || true
        chmod -R 700 /etc/udev

        describe Running on blank host
        register_test retvalshouldbe 0
        dismiss_count_for_test
        # shellcheck disable=2154
        run blank /opt/debian-cis/bin/hardening/"${script}".sh --audit-all

        echo 'ACTION=="add", SUBSYSTEMS=="usb", TEST=="authorized_default", ATTR{authorized_default}="0"' >/etc/udev/rules.d/10-CIS_99.2_usb_devices.sh

        describe compliant
        register_test retvalshouldbe 0
        run compliant /opt/debian-cis/bin/hardening/"${script}".sh --audit-all

        # TODO fill comprehensive tests

        # Cleanup
        rm /etc/udev/rules.d/10-CIS_99.2_usb_devices.sh
    fi
}
