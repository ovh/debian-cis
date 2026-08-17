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

## Script invocation and configuration files

### Two invocation modes

A script can be called in two ways, and `lib/main.sh` detects the mode automatically via `[ -L "$0" ]`:

| Mode | Path example | `$0` is |
|------|-------------|---------|
| **Direct** (canonical) | `bin/hardening/the_script.sh` | a regular file |
| **Versioned** | `versions/x/1.2.3_the_script.sh` | a symbolic link → `bin/hardening/the_script.sh` |

### Configuration file naming

| Mode | cfg file created | cfg link created |
|------|-----------------|-----------------|
| Direct | `etc/conf.d/the_script.cfg` | — |
| Versioned | `etc/conf.d/the_script.cfg` (real file) | `etc/conf.d/1.2.3_the_script.cfg` → cfg file |

The real config file is always named after the **target** script (`the_script.cfg`).  
The versioned name (`1.2.3_the_script.cfg`) is a symlink, created or updated automatically.

### Configuration file management rules (lib/main.sh)

1. **conf.d not writable/executable** → warn, skip file creation entirely.
2. **cfg file does not exist** → create it with a header + `status=audit` (or output of `check_config()` if defined).
3. **cfg link does not exist** → create it as a symlink pointing to the cfg file.
4. **cfg link already exists and is a symlink, correct target** → no-op (idempotent).
5. **cfg link already exists and is a symlink, wrong target** → update it with `ln -fs`.
6. **cfg link is a writable regular file** → replace it with a symlink.
7. **cfg link is a non-writable regular file** → warn, leave it in place.

### Tests covering these cases

`tests/test_main_conf_links.sh` is a standalone test script (independent of the hardening test harness) that exercises all 7 cases above. Run it directly:

```bash
bash tests/test_main_conf_links.sh
```

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

For newly created scripts, omit CIS recommendation numbering from human-readable titles/comments. Example: use `Ensure accounts without a valid login shell are locked (Automated)`, not `5.4.2.8 Ensure accounts without a valid login shell are locked (Automated)`.

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
- Allowed examples: `cat`, `grep`, `sed`, `awk`, `systemctl`, `dpkg-query`, `auditctl -s`, `augenrules --check`

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

For checks that are intentionally **manual remediation only** (script `apply()` cannot auto-fix by design), tests may skip `--apply` and instead:
1. Create non-compliant state and verify `retvalshouldbe 1`
2. Perform documented manual remediation inside the test
3. Re-audit and verify `retvalshouldbe 0`
4. Restore/cleanup

### Key rules

- `retvalshouldbe 0` = compliant, `retvalshouldbe 1` = non-compliant
- `contain "..."` — only use when you are certain that exact string appears in `audit()` output
- If a package is installed in a test → remove it + `apt-get autoremove -y` at the end
- If a script depends on a package, tests should cover both cases when feasible: package installed and package not installed (not-applicable path).
- Restore modified config files at end of test
- In tests, if `${script}` (or other harness vars) is used in local variable assignments, add `# shellcheck disable=2154` immediately above those lines.
- If non-compliant state cannot be created (config absent), use `skip` + `register_test`/`run` inside the conditional block
- For dependency-aware package/service tests, if a non-compliant state cannot be reliably created in the current environment (for example package is required and units cannot be forced to enabled/active), skip the remediation path with `skip` + `register_test`/`run` instead of forcing `retvalshouldbe 1`
- Do not use `mount`/`remount` in containers; skip those tests with a container check
- For scripts interacting with audit runtime (auditctl/augenrules), check `auditctl -s` availability and skip if not present.
- For scripts interacting with systemd, use `is_systemctl_running` and skip when systemd is not running.
- When output is unpredictable (blank system), use `dismiss_count_for_test`
- When a test requires two packages (e.g. `gdm` vs `gdm3`), detect which is present and adapt config paths accordingly

### Test comprehensiveness

For all scripts, tests should cover the broadest realistic set of states:

1. **Missing prerequisites** (dependency/package/service/file absent or unavailable) → `retvalshouldbe 1` or `skip` if state cannot be reliably created
2. **Missing target configuration** (expected file/rule/value absent) → `retvalshouldbe 1`
3. **Broken/incomplete configuration** (present but malformed, partial, wrong value, wrong owner/perms) → `retvalshouldbe 1`
4. **Asymmetric/inconsistent state** (configured in one layer but not in effective runtime) → `retvalshouldbe 1`
5. **Compliant state** (after apply/fix, all checks pass) → `retvalshouldbe 0`

Backup/restore all modified system files at test boundaries. Isolate test scenarios by resetting runtime state when needed (for example `auditctl -D` for audit runtime tests).

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
