# shellcheck shell=bash
# run-shellcheck

REPO_ROOT=$(cd "$(dirname "$0")/../.." && pwd)
LIB_DIR="$REPO_ROOT/lib"

TMPDIR=$(mktemp -d -p "$HOME" cis-main-conf-test.XXXXXX)
WORK_DIR="$TMPDIR/work"
CONF_DIR="$TMPDIR/etc"
CONF_D_DIR="$CONF_DIR/conf.d"
DEFAULT_SCRIPT_NAME="the_script"
DEFAULT_SCRIPT_NUMBER="1.2.3"
DEFAULT_HARDENING_LEVEL="1"
DEFAULT_CIS_VERSION="default"

mkdir -p "$WORK_DIR/bin/hardening" "$WORK_DIR/versions/$DEFAULT_CIS_VERSION" "$WORK_DIR/tmp" "$CONF_D_DIR"

# required by main.sh, will define default LOGLEVEL for instance
cp "$REPO_ROOT/etc/hardening.cfg" "$CONF_DIR/hardening.cfg"

# required for bin/hardening.sh and hardening.cfg
export CIS_LIB_DIR="$LIB_DIR"
export CIS_CHECKS_DIR="$WORK_DIR/bin/hardening"
export CIS_CONF_DIR="$CONF_DIR"
export CIS_TMP_DIR="$WORK_DIR/tmp"
export CIS_VERSIONS_DIR="$WORK_DIR/versions"

fail() {
    echo "FAIL: $*" >&2
    exit 1
}

cleanup_tmpdir() {

    chmod -R u+rwX "$TMPDIR" 2>/dev/null || true
    rm -rf "$TMPDIR"
}

run_createconfig() {
    local path="$1"
    local output
    [ -x "$path" ] || fail "expected executable: $path"
    output=$("$path" --create-config-files-only 2>&1) || fail "command failed for $path: $output"
    echo "$output"
}

write_test_script() {

    if [ "$#" -lt 3 ]; then
        echo "using default values to write test script"
        local script_name="$DEFAULT_SCRIPT_NAME"
        local script_number="$DEFAULT_SCRIPT_NUMBER"
        local hardening_level="$DEFAULT_HARDENING_LEVEL"
    else
        local script_name="$1"
        local script_number="$2"
        local hardening_level="$3"
    fi

    local script_path="$WORK_DIR/bin/hardening/$script_name.sh"
    local script_link="$WORK_DIR/versions/$DEFAULT_CIS_VERSION/${script_number}_${script_name}.sh"

    cat >"$script_path" <<EOF
#!/bin/bash
set -e
set -u
HARDENING_LEVEL=$hardening_level
DESCRIPTION="dummy script for engine tests"
check_config() { :; }
audit() { :; }
apply() { :; }
CIS_LIB_DIR="$LIB_DIR"
CIS_CONF_DIR="$CONF_DIR"
. "\${CIS_LIB_DIR}/main.sh"
EOF

    chmod +x "$script_path"
    ln -s "$script_path" "$script_link"
}

assert_file_exists() {
    [ -f "$1" ] || fail "expected file to exist: $1"
}

assert_not_exists() {
    [ ! -e "$1" ] || fail "expected path to not exist: $1"
}

assert_status() {
    local cfg_file="$1"
    local expected_status="$2"
    [ -f "$cfg_file" ] || fail "expected config file to exist: $cfg_file"
    local actual_status
    actual_status=$(grep -E '^status=' "$cfg_file" | cut -d= -f2)
    [ "$actual_status" = "$expected_status" ] || fail "expected status=$expected_status in $cfg_file, got: $actual_status"
}

