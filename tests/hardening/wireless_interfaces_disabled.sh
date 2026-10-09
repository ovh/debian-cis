# shellcheck shell=bash
# run-shellcheck
test_audit() {
    local fixture check_copy apply_check
    # shellcheck disable=2154
    local check_path="${CIS_CHECKS_DIR}/${script}.sh"

    describe Running on blank host
    register_test retvalshouldbe 0
    run blank "$check_path" --audit-all

    fixture=$(mktemp -d)
    chmod 755 "$fixture"
    install -d -m 755 "$fixture/net" "$fixture/modules"
    install -d -m 777 "$fixture/modprobe"
    check_copy="$fixture/wireless_interfaces_disabled.sh"

    # Exercise the real check through the normal root/secaudit harness while
    # redirecting sysfs and modprobe paths to an isolated fixture.
    sed \
        -e "s|^WIRELESS_SYS_CLASS_NET=.*|WIRELESS_SYS_CLASS_NET=\"$fixture/net\"|" \
        -e "s|^WIRELESS_MODPROBE_DIR=.*|WIRELESS_MODPROBE_DIR=\"$fixture/modprobe\"|" \
        "$check_path" >"$check_copy"
    chmod 755 "$check_copy"

    mkdir -p "$fixture/net/wlan0/wireless" "$fixture/net/wlan0/device/driver" "$fixture/modules/iwlwifi"
    chmod -R a+rX "$fixture/net" "$fixture/modules"
    ln -s "$fixture/modules/iwlwifi" "$fixture/net/wlan0/device/driver/module"

    describe Detecting an active wireless driver
    register_test retvalshouldbe 1
    run active_driver "$check_copy" --audit-all

    rm -rf "$fixture/net/wlan0"
    describe Accepting a system without wireless interfaces
    register_test retvalshouldbe 0
    run no_wireless "$check_copy" --audit-all

    mkdir -p "$fixture/net/wlan0/wireless"
    chmod -R a+rX "$fixture/net"
    describe Failing when a wireless driver cannot be identified
    register_test retvalshouldbe 1
    run unknown_driver "$check_copy" --audit-all

    # Verify apply() separately through the same root/secaudit harness. It must
    # preserve existing content and add each future-load rule only once.
    apply_check="$fixture/check_apply.sh"
    cat >"$apply_check" <<EOF
#!/bin/bash
set -eu
# shellcheck source=/dev/null
source <(sed '/^# Source Root Dir Parameter/,\$d' "$check_path")
WIRELESS_MODPROBE_DIR="$fixture/modprobe"
WIRELESS_MODULES=(iwlwifi)
info() { :; }
config="\$WIRELESS_MODPROBE_DIR/cis-wireless-iwlwifi.conf"
rm -f "\$config"
printf '# keep existing content\\n' >"\$config"
apply
apply
grep -qxF '# keep existing content' "\$config"
[ "\$(grep -cFx 'install iwlwifi /bin/false' "\$config")" = 1 ]
[ "\$(grep -cFx 'blacklist iwlwifi' "\$config")" = 1 ]
EOF
    chmod 755 "$apply_check"

    describe Writing idempotent future-load blocking rules
    register_test retvalshouldbe 0
    run apply_rules "$apply_check"

    rm -rf -- "$fixture"
}
