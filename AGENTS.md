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

HARDENING_LEVEL=<1-5>
DESCRIPTION="..."

# Global state (prefix must be unique across all scripts)
MY_SCRIPT_VAR=1   # 1 = false/failure, 0 = true/success

audit()      { ... }   # read-only; calls ok/crit
apply()      { ... }   # makes changes; uses global state set by audit()
check_config() { : }   # optional; define configurable vars here
```

`audit()` is always called before `apply()`. Never duplicate logic — use global variables set in `audit()` instead of re-checking in `apply()`.

### HARDENING_LEVEL policy

- `1` — very basic policy; failure at this level indicates severe misconfiguration with potentially huge security impact.
- `2` — basic policy; good-practice rules that should not break most systems once applied.
- `3` — best-practices policy; passing all tests may require configuration changes (for example partitioning choices).
- `4` — high-security policy; passing all tests may be time-consuming and require significant workflow adaptation.
- `5` — placebo policy; rules that may be difficult to apply and maintain, with questionable security benefits.

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

### State variable hygiene

- Keep a single source of truth for a given state in a script. Do not duplicate the same status in both a local variable and a global variable.
- Avoid redundant assignments to default values (for example, setting a variable to `0` in a branch when it is already initialized to `0`).
- Use global state variables in `apply()` only when they are set by `audit()`.
- Prefer declaring state globals once at file scope with their default value, instead of reinitializing them to the same value at the start of `audit()`.
- Reinitialize a state variable in `audit()` only when its value must be explicitly cleared or rebuilt for that run (for example strings, lists, or accumulators).

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

### Configuration lifecycle: `create_config()` and `check_config()`

Scripts can define two optional functions to manage user-configurable variables:

**`create_config()`** — Called **once**, when config file is first created by `lib/main.sh`:
- Generates the initial template in `etc/conf.d/the_script.cfg`
- Should document all user-overridable variables with comments
- **Must include `status=audit`** as the first line
- Example:
  ```bash
  create_config() {
      cat <<EOF
  status=audit
  # User-configurable: approved ciphers (comma-separated)
  SSHD_CIPHERS_LINE='Ciphers aes256-gcm@openssh.com,aes128-gcm@openssh.com,aes256-ctr,aes192-ctr,aes128-ctr'
  EOF
  }
  ```

**`check_config()`** — Called **every execution**, before `audit()` runs (in both audit and enabled modes):
- Initializes global variables with defaults **only if they are empty**
- Allows cfg file values to override defaults (user edits cfg → values take precedence)
- Does NOT regenerate the cfg file
- Example:
  ```bash
  check_config() {
      if [ -z "$SSHD_CIPHERS_LINE" ]; then
          SSHD_CIPHERS_LINE="Ciphers aes256-gcm@openssh.com,aes128-gcm@openssh.com,aes256-ctr,aes192-ctr,aes128-ctr"
      fi
  }
  ```

**User workflow:**
1. First run: cfg created with template from `create_config()` → user sees documentation + defaults
2. User edits cfg to customize: `vim /opt/debian-cis/etc/conf.d/the_script.cfg`
3. Next run: `check_config()` loads cfg values, uses them in `audit()` and `apply()`

**Key principle:** `check_config()` provides **intelligent defaults** that don't override user customization.

**Variable naming stability:** When modifying an existing script, **preserve the names of variables** originally defined in `create_config()`. If a script previously offered `OPTIONS` or another variable name for customization, keep using that name even if refactoring internally. Renaming variables breaks existing user configurations. Only add new variable names; do not remove or rename existing ones.

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
<<<<<<< HEAD
- For dependency-aware package/service tests, if a non-compliant state cannot be reliably created in the current environment (for example package is required and units cannot be forced to enabled/active), skip the remediation path with `skip` + `register_test`/`run` instead of forcing `retvalshouldbe 1`
=======
- For dependency-aware package/service tests, first try to force a non-compliant state by installing the package and, when `systemctl` is available, unmasking/enabling/starting the related units. If the audit still returns compliant, skip the remediation path cleanly instead of forcing `retvalshouldbe 1`.
>>>>>>> damcav35/update_scripts_3
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

## State variable hygiene

**Golden rules for global state management:**

1. **Single source of truth**: Declare each global state variable **once** at file scope with its default value (usually `1`, meaning non-compliant/not-set). Never duplicate with local variables (e.g., `l_gdm_installed`).

2. **No redundant reinitialization in `audit()`**: Do NOT reset state variables at the top of `audit()`. They already have correct defaults from file scope. Only SET them when logic determines a new value (e.g., when a check passes, set to `0`).

3. **Configurable variables use empty defaults**: Variables that users may override via cfg are declared empty at scope level:
   ```bash
   SSHD_CIPHERS_LINE=""    # empty at top
   ```
   Then `check_config()` fills them if still empty (allowing user cfg values to take precedence).

4. **`apply()` trusts `audit()`'s state**: Never re-check conditions in `apply()`. Use the global variables set by `audit()` to decide what to do. This avoids duplicating logic and ensures consistency.

5. **Accumulators are the exception**: If a variable accumulates results across a loop (e.g., `bad_ciphers="${bad_ciphers:+$bad_ciphers,}$new_value"`), it's OK to initialize it locally in `audit()` since each run needs a fresh accumulator. But non-accumulator state booleans should live at scope.

**Example pattern (sshd_ciphers.sh):**
```bash
# Global scope
SSHD_CIPHERS_PKG_INSTALLED=1  # default: not installed
SSHD_CIPHERS_OK=1             # default: non-compliant
SSHD_CIPHERS_LINE=""          # default: empty, filled by check_config()

check_config() {
    if [ -z "$SSHD_CIPHERS_LINE" ]; then
        SSHD_CIPHERS_LINE="Ciphers aes256-gcm..."  # only if not set
    fi
}

audit() {
    # Check package, set SSHD_CIPHERS_PKG_INSTALLED to 0 if found
    # No redundant "=1" at top—already default
    
    # Check ciphers against allow-list
    # Set SSHD_CIPHERS_OK=0 if compliant
}

apply() {
    # Check SSHD_CIPHERS_PKG_INSTALLED and SSHD_CIPHERS_OK
    # Never re-check—trust audit()
}
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
