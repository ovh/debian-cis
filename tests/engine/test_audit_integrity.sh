#!/bin/bash
# run-shellcheck
set -eu
source tests/engine/lib.sh
trap cleanup_tmpdir EXIT
write_test_script service_http 1.1.1 1
write_test_script service_dns 1.1.2 1
sed -i '/^DESCRIPTION=/a HARDENING_EXCEPTION=http' "$WORK_DIR/bin/hardening/service_http.sh"
sed -i '/^DESCRIPTION=/a HARDENING_EXCEPTION=dns' "$WORK_DIR/bin/hardening/service_dns.sh"

"$REPO_ROOT/bin/hardening.sh" --set-hardening-level 2 --allow-service http --allow-unsupported-distribution >/dev/null
assert_status "$CONF_D_DIR/1.1.1_service_http.cfg" disabled
assert_status "$CONF_D_DIR/1.1.2_service_dns.cfg" enabled

# If the canonical file already exists but a version alias is missing, status
# updates must recreate the alias rather than leaving the versioned check unable
# to load its configuration.
rm -f "$CONF_D_DIR/1.1.2_service_dns.cfg"
assert_file_exists "$CONF_D_DIR/service_dns.cfg"
"$REPO_ROOT/bin/hardening.sh" --set-hardening-level 2 --allow-service http --allow-unsupported-distribution >/dev/null
[ -L "$CONF_D_DIR/1.1.2_service_dns.cfg" ] || fail 'missing versioned configuration link was not recreated'
assert_status "$CONF_D_DIR/1.1.2_service_dns.cfg" enabled

"$REPO_ROOT/bin/hardening.sh" --audit --allow-unsupported-distribution >/dev/null
assert_status "$CONF_D_DIR/service_http.cfg" disabled
"$REPO_ROOT/bin/hardening.sh" --audit-all-enable-passed --allow-unsupported-distribution >/dev/null
[ -L "$CONF_D_DIR/1.1.1_service_http.cfg" ] || fail 'enabling passed checks replaced a configuration symlink'
assert_status "$CONF_D_DIR/service_http.cfg" enabled

# A non-zero status outside the check protocol must not disappear from the summary.
printf '#!/bin/bash\nexit 127\n' >"$WORK_DIR/bin/hardening/service_http.sh"
result=0
"$REPO_ROOT/bin/hardening.sh" --audit-all --summary-json --allow-unsupported-distribution >"$WORK_DIR/tmp/summary" || result=$?
[ "$result" = 3 ] || fail "runtime failure returned $result rather than launcher error status 3"
grep -q '"error_checks": 1' "$WORK_DIR/tmp/summary" || fail 'runtime failure not counted'
echo 'PASS: service exceptions, canonical state and execution errors'
