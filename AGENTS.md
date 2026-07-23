# CIS Debian Hardening — Copilot Instructions

Collection of bash scripts implementing [CIS Debian Linux Benchmark](https://www.cisecurity.org/benchmark/debian_linux).

## Layout

```
bin/hardening/   # one script per CIS recommendation
tests/hardening/ # one test per script (same filename)
lib/             # common.sh, utils.sh, main.sh, constants.sh
src/skel         # skeleton for new scripts
src/skel.test    # skeleton for new tests
```

- There is one hardening script per CIS recommendation.
- CIS recommendation numbers (for example `1.4.2.1`) must not appear in script filenames.

---

## Script standards

### Required structure

```bash
set -e
set -u

HARDENING_LEVEL=<1-3>
DESCRIPTION="..."

# Global state (prefix must be unique across all scripts)
MY_SCRIPT_VAR=1   # 1 = false/failure, 0 = true/success

audit()      { ... }   # read-only; calls ok/crit
apply()      { ... }   # makes changes; uses global state set by audit()
check_config() { : }   # optional; define configurable vars here
```

`audit()` is always called before `apply()`. Never duplicate logic — use global variables set in `audit()` instead of re-checking in `apply()`.

### ok / crit / info

- `ok "..."` — recommendation is met
- `crit "..."` — recommendation is NOT met
- `info "..."` — informational, used in `apply()`

### FNRET convention (lib/utils.sh)

```bash
is_pkg_installed "gdm3"
if [ "$FNRET" = 0 ]; then   # 0 = installed / true
    ...
fi
```

Never define `FNRET` in scripts. Use explicit `if/then` — never `command && { ... }` (incompatible with `set -e`).

### Variable convention

```
0 = true / success
1 = false / failure   ← always initialize to 1
```

Global variable names must be unique across all scripts. Use a script-specific prefix (e.g. `GDM_AR_`, `AUDIT_LOG_`).

### Package detection (multiple packages)

```bash
PACKAGES='gdm gdm3'
MY_SCRIPT_INSTALLED=1   # initialize to 1 (not installed)

for l_package in $PACKAGES; do
    is_pkg_installed "$l_package"
    if [ "$FNRET" = 0 ]; then
        ok "Package $l_package is installed"
        MY_SCRIPT_INSTALLED=0
        break
    fi
done

if [ "$MY_SCRIPT_INSTALLED" -ne 0 ]; then
    ok "Package not installed - not applicable"
    return
fi
```

### Key-value config files (with spaces around `=`)

Always match with and without spaces:

- When `apply()` updates key-value files, remove existing occurrences of the key first to avoid duplicates, then write the expected value.

```bash
grep -Psir -- '^\h*my_key\h*=\h*value\b' /etc/some.conf
```

### INI-style config files (dconf, etc.)

When `apply()` writes to a sectioned file:

1. If file exists → remove all instances of keys being modified (avoid duplicates)
2. If file doesn't exist → create it with the section header
3. Ensure section header exists
4. Append key after header with `sed -i '/^\[section\]/a key=value'`
5. **Never** use `cat >` — it destroys existing content

```bash
if [ -f "$l_kfile" ]; then
    sed -i '/^\s*my_key\s*=/d' "$l_kfile"
else
    echo "[my/section]" >"$l_kfile"
fi
if ! grep -q '^\[my/section\]' "$l_kfile"; then
    echo "[my/section]" >>"$l_kfile"
fi
sed -i '/^\[my\/section\]/a my_key=value' "$l_kfile"
```

### Multi-file compliance checks

When checking config across multiple files, verify **ALL** files before deciding compliance. Do not return early on finding a correct value — a later file may override it.

### sudo rules

Audit runs as non-root. Use `$SUDO_CMD` for read-only commands only:
- Allowed: `cat`, `grep`, `sed`, `awk`, `systemctl`, `dpkg-query`
- **Not allowed**: `apt`, `mount`, `chown`, `chmod`, `mv`, `cp`, `rm`

Sudo rules are in `cisharden.sudoers`.

### systemd

```bash
is_systemctl_running
if [ "$FNRET" != 0 ]; then
    warn "systemd not running, skipping"
    return
fi
```

### Optional configurable parameters

```bash
MY_OPTION=""   # declared empty at top

check_config() {
    MY_OPTION="default_value"
    # output file must include: status=audit
}
```

`create_config` may exist in older scripts/documentation and follows the same rule: generated config must include `status=audit`.

---

## Test standards

### Required flow

```
1. Create non-compliant state    → run --audit-all → register_test retvalshouldbe 1 → run noncompliant
2. Apply fix                     → sed 's/audit/enabled/' cfg && script --apply
3. Verify compliant state        → run --audit-all → register_test retvalshouldbe 0 → run resolved
4. Restore/cleanup
```

### Key rules

- `retvalshouldbe 0` = compliant, `retvalshouldbe 1` = non-compliant
- `contain "..."` — only use when you are certain that exact string appears in `audit()` output
- If a package is installed in a test → remove it + `apt-get autoremove -y` at the end
- If a script depends on a package, tests should cover both cases when feasible: package installed and package not installed (not-applicable path).
- Restore modified config files at end of test
- If non-compliant state cannot be created (config absent), use `skip` + `register_test`/`run` inside the conditional block
- Do not use `mount`/`remount` in containers; skip those tests with a container check
- For scripts interacting with systemd, use `is_systemctl_running` and skip when systemd is not running.
- When output is unpredictable (blank system), use `dismiss_count_for_test`
- When a test requires two packages (e.g. `gdm` vs `gdm3`), detect which is present and adapt config paths accordingly

### Package test pattern

```bash
# detect which variant is installed
if dpkg -s gdm3 >/dev/null 2>&1; then
    gdm_pkg="gdm3"; gdm_conf_dir="/etc/gdm3"
else
    gdm_pkg="gdm"; gdm_conf_dir="/etc/gdm"
fi
DEBIAN_FRONTEND=noninteractive apt-get install -y "$gdm_pkg" ... || true
# ... tests ...
apt-get remove -y "$gdm_pkg" || true
apt-get autoremove -y || true
```

---

## Workflow: creating a new script

```
New script checklist:
- [ ] Copy src/skel → bin/hardening/<name>.sh
- [ ] Copy src/skel.cfg → etc/conf.d/<name>.cfg
- [ ] Copy src/skel.test → tests/hardening/<name>.sh
- [ ] Set unique global variable prefix
- [ ] Implement audit() (read-only, ok/crit)
- [ ] Implement apply() (uses global state from audit)
- [ ] Run shellcheck bin/hardening/<name>.sh
- [ ] Run shellfmt on script and test
- [ ] Verify test flow: noncompliant → apply → resolved
- [ ] Check hooks/check_has_test.sh passes
```

---

## Tools

Every script and test must pass `shellcheck` and `shellfmt` (see `hooks/`).
