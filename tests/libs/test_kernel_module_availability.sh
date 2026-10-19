#!/bin/bash
# run-shellcheck
set -eu
repo=$(cd "$(dirname "$0")/../.." && pwd)
fixture=$(mktemp -d)
trap 'rm -rf -- "$fixture"' EXIT
# Exercise the real availability helper against a synthetic kernel configuration.
# No module is loaded, unloaded or disabled on the machine running this test.
source "$repo/lib/utils.sh"
fixture_read() {
    [ "$1" = grep ] || return 1
    shift
    if [ "$1" = -l ]; then
        grep -l "$2" "$fixture/kernel.config"
    else
        grep "$1" "$fixture/kernel.config"
    fi
}
# shellcheck disable=2034
SUDO_CMD=fixture_read
is_kernel_monolithic() { IS_MONOLITHIC_KERNEL=1; }
is_kernel_module_loaded() { FNRET=$loaded; }
is_kernel_module_disabled() { FNRET=$blocked; }
# shellcheck disable=2034
IS_MONOLITHIC_KERNEL=1
# shellcheck disable=2034
IS_CONTAINER=0
ok() { :; }
info() { :; }
debug() { :; }
crit() { failures=$((failures + 1)); }
total=0
errors=0
while read -r script option; do
    for scenario in available absent blocked loaded; do
        if (
            # shellcheck source=/dev/null
            source <(sed '/^# Source Root Dir Parameter/,$d' "$repo/bin/hardening/$script.sh")
            loaded=1
            blocked=1
            failures=0
            case "$scenario" in
            available) printf '%s=m\n' "$option" >"$fixture/kernel.config" ;;
            absent) printf '# %s is not set\n' "$option" >"$fixture/kernel.config" ;;
            blocked)
                printf '%s=m\n' "$option" >"$fixture/kernel.config"
                blocked=0
                ;;
            loaded)
                printf '%s=m\n' "$option" >"$fixture/kernel.config"
                loaded=0
                ;;
            esac
            audit
            case "$scenario" in
            available | loaded) [ "$failures" -gt 0 ] ;;
            absent | blocked) [ "$failures" = 0 ] ;;
            esac
        ) then
            echo "PASS: $script $scenario"
        else
            echo "FAIL: $script $scenario" >&2
            errors=$((errors + 1))
        fi
        total=$((total + 1))
    done
done <<'CASES'
disable_cramfs CONFIG_CRAMFS
disable_freevxfs CONFIG_VXFS_FS
disable_hfs CONFIG_HFS_FS
disable_hfsplus CONFIG_HFSPLUS_FS
disable_jffs2 CONFIG_JFFS2_FS
disable_squashfs CONFIG_SQUASHFS
disable_udf CONFIG_UDF_FS
disable_usb_storage CONFIG_USB_STORAGE
disable_dccp CONFIG_IP_DCCP
disable_sctp CONFIG_IP_SCTP
disable_rds CONFIG_RDS
disable_tipc CONFIG_TIPC
CASES
printf 'Module scenarios: %s; failures: %s\n' "$total" "$errors"
[ "$errors" = 0 ]
