#!/bin/bash
# run-shellcheck
set -e
set -u

REPO_ROOT=$(cd "$(dirname "$0")/.." && pwd)
LIB_DIR="$REPO_ROOT/lib"

tmpdir=$(mktemp -d -p "$HOME" cis-main-conf-test.XXXXXX)

cleanup() {
    chmod -R u+rwX "$tmpdir" 2>/dev/null || true
    rm -rf "$tmpdir"
}
trap cleanup EXIT HUP INT

WORK_DIR="$tmpdir/work"
CONF_DIR="$tmpdir/etc"
CONF_D_DIR="$CONF_DIR/conf.d"

SCRIPT_REAL="$WORK_DIR/bin/hardening/the_script.sh"
SCRIPT_LINK="$WORK_DIR/versions/x/1.2.3_the_script.sh"
CFG_FILE="$CONF_D_DIR/the_script.cfg"
CFG_LINK="$CONF_D_DIR/1.2.3_the_script.cfg"

mkdir -p "$WORK_DIR/bin/hardening" "$WORK_DIR/versions/x" "$CONF_D_DIR"

cat >"$SCRIPT_REAL" <<EOF
#!/bin/bash
set -e
set -u
HARDENING_LEVEL=1
DESCRIPTION="dummy script for main.sh config-link tests"
LOGLEVEL=info
check_config() { :; }
audit() { :; }
apply() { :; }
CIS_LIB_DIR="$LIB_DIR"
CIS_CONF_DIR="$CONF_DIR"
. "\${CIS_LIB_DIR}/main.sh"
EOF
chmod +x "$SCRIPT_REAL"
ln -s "$SCRIPT_REAL" "$SCRIPT_LINK"

fail() {
    echo "FAIL: $*" >&2
    exit 1
}

assert_file_exists() {
    [ -f "$1" ] || fail "expected file to exist: $1"
}

assert_not_exists() {
    [ ! -e "$1" ] || fail "expected path to not exist: $1"
}

assert_is_symlink() {
    [ -L "$1" ] || fail "expected symlink: $1"
}

assert_not_symlink() {
    [ ! -L "$1" ] || fail "expected regular file, got symlink: $1"
}

assert_symlink_target() {
    got=$(readlink -f "$1")
    exp=$(readlink -f "$2")
    [ "$got" = "$exp" ] || fail "bad symlink target for $1 (got: $got, expected: $exp)"
}

assert_contains() {
    needle="$1"
    haystack="$2"
    echo "$haystack" | grep -Fq "$needle" || fail "expected output to contain: $needle"
}

run_createconfig() {
    path="$1"
    output=$("$path" --create-config-files-only 2>&1) || fail "command failed for $path: $output"
    echo "$output"
}

reset_conf_d() {
    chmod 700 "$CONF_D_DIR"
    rm -f "$CONF_D_DIR"/*
}

echo "Case 1: script called as a regular file -> create only the_script.cfg"
reset_conf_d
run_createconfig "$SCRIPT_REAL" >/dev/null
assert_file_exists "$CFG_FILE"
assert_not_exists "$CFG_LINK"

echo "Case 2: script called as a symlink -> create cfg file + cfg symlink"
reset_conf_d
run_createconfig "$SCRIPT_LINK" >/dev/null
assert_file_exists "$CFG_FILE"
assert_is_symlink "$CFG_LINK"
assert_symlink_target "$CFG_LINK" "$CFG_FILE"

echo "Case 3: existing symlink points to wrong target -> must be fixed"
reset_conf_d
echo "status=audit" >"$CFG_FILE"
ln -s /tmp/wrong-target "$CFG_LINK"
run_createconfig "$SCRIPT_LINK" >/dev/null
assert_is_symlink "$CFG_LINK"
assert_symlink_target "$CFG_LINK" "$CFG_FILE"

echo "Case 4: existing writable regular file at cfg_link -> replace with symlink"
reset_conf_d
echo "status=audit" >"$CFG_FILE"
echo "old" >"$CFG_LINK"
chmod 644 "$CFG_LINK"
run_createconfig "$SCRIPT_LINK" >/dev/null
assert_is_symlink "$CFG_LINK"
assert_symlink_target "$CFG_LINK" "$CFG_FILE"

echo "Case 5: existing non-writable regular file at cfg_link -> warn and keep file"
if [ "$(id -u)" -eq 0 ]; then
    echo "Case 5 skipped: running as root (root bypasses regular write checks/ACLs)"
else
    reset_conf_d
    echo "status=audit" >"$CFG_FILE"
    echo "keepme" >"$CFG_LINK"
    chmod 444 "$CFG_LINK"
    output=$(run_createconfig "$SCRIPT_LINK")
    assert_not_symlink "$CFG_LINK"
    [ "$(cat "$CFG_LINK")" = "keepme" ] || fail "expected non-writable cfg_link file to be preserved"
    assert_contains "cannot manage it" "$output"
fi

echo "Case 6: conf.d not writable/executable -> warn and no create"
if [ "$(id -u)" -eq 0 ]; then
    echo "Case 6 skipped: running as root (root may bypass regular directory write checks)"
else
    reset_conf_d
    chmod 500 "$CONF_D_DIR"
    output=$(run_createconfig "$SCRIPT_REAL")
    assert_not_exists "$CFG_FILE"
    assert_contains "is not writable" "$output"
fi

echo "Case 7: existing correct symlink -> must be idempotent and succeed"
chmod 700 "$CONF_D_DIR"
rm -f "$CONF_D_DIR"/*
echo "status=audit" >"$CFG_FILE"
ln -s "$CFG_FILE" "$CFG_LINK"
run_createconfig "$SCRIPT_LINK" >/dev/null
assert_is_symlink "$CFG_LINK"
assert_symlink_target "$CFG_LINK" "$CFG_FILE"

echo "PASS: all main.sh config/link management cases succeeded"
