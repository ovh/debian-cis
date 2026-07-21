# Project Overview

This project is a collection of bash scripts implementing Center for CIS for debian: https://www.cisecurity.org/benchmark/debian_linux

## Folder Structure

- `bin/hardening`: contains the scripts implementing CIS recommendations
- `tests/hardening`: contains the tests
- `lib`: contains common functions for the scripts

## Organization

- There is one script for each CIS recommendation
- each script has an associated test, with the same name
- the CIS recommendation number (ex: 1.4.2.1) does not appear in the script name

## Scripts coding Standards

- each script has to use "set -e" and "set -u"
- each script implements an "audit" and a "apply" function
- "audit" does not do any modification
- if the recommendation is conform, "audit" must use the "ok" function to write a message
- if the recommendation is not conform, "audit" must use the "crit" function to write a message
- "apply" ensures the local configuration is conform with the CIS recommendation
- "apply" is allowed to make changes
- when "apply" modifies configuration files with key-value pairs, it must ensure no duplicate keys exist (remove all instances of a key before adding the correct value)
- when "apply" modifies INI-style configuration files with sections (like dconf files), it must:
  1. Check if the file exists; if it exists, remove all instances of the keys being modified to avoid duplicates
  2. If the file doesn't exist, create it with the section header
  3. Verify the section header exists, add it if missing
  4. Add the key-value pairs after the section header using `sed -i '/^\[section\]/a key=value'`
  5. Never use `cat >` to overwrite the entire file as it destroys existing content
  6. Example pattern from gdm_disable_autorun.sh and gdm_disable_automount_overriden.sh

- in the workflow execution, "audit" will be executed before "apply", there should be no code duplication in "audit" and "apply" in scripts
- if a function in "audit" is called to set global variables describing a state, it should not be called again in "apply", instead the global variables should be used to check if the state is conform or not, and to apply the correct configuration if needed
- global variables names has to be unique across all scripts
- scripts should use common function from lib/utils.sh when possible
- function results from lib/utils.sh are evaluated using the value of the variable FNRET
- FNRET value 0 means true / success
- FNRET value 1 means false / failure
- FNRET should not be defined in the scripts
- when using variables, 0 means true / success
- when using variables, 1 means false / failure
- when using variables to represent true / false or success / failure, set the initial value to 1 (false / failure), and set it to 0 (true / success) when the condition is met
- avoid using the `command && { ... }` construct as it is incompatible with `set -e`: if the command returns non-zero (failure), the entire expression returns non-zero which causes the script to exit immediately; instead, use explicit `if-then` structures that check `$FNRET` after calling functions from lib/utils.sh

- "create_config" is an optional function in the scripts: if an option has to be made configurable by the user, it can be set as global variable without a value, then defined in the "create_config" function
- when using "create_config", the output file of the function must contains "status=audit"
- when a script requires the presence of a package, the associated test should run tests with and without the package.
- when a script requires to interact with systemd, use the function "is_systemctl_running" from lib/utils.sh to check if systemd is running, and skip the test if not
- when checking configuration across multiple files, verify ALL files before determining compliance; if any file contains an incorrect value for an option, fail immediately - do not return early on finding correct values as later files may override with incorrect values
- consider that the audit scripts are executed with a non root user. sudo can be used via the "$SUDO_CMD". The sudo rules are defined "cisharden.sudoers"
- we are only allowed to set sudo on commands that do not have side effects on the system, like "cat", "grep", "sed", "awk", "systemctl", "dpkg-query" ; we are not allowed to set sudo on commands that can modify the system, like "apt", "mount", "remount", "umount", "chown", "chmod", "mv", "cp", "rm", etc.

## Tests coding Standards

- each test should test a non conform scenario
- each test should use the script "apply" after the non conform scenario
- each test should then test a conform scenario
- a test can install a package if required
- if a test installs a package, it should be removed at the end of the test, and also run "apt autoremove" to remove any dependency that was installed with the package
- when a test uses the "contain" keyword, it must ensures the output is present in the corresponding script "audit" function. In case of doubt, do not use "contain", and do not check the output of the "audit" function in the test
- when a test modifies configuration files, it should restore the original configuration at the end of the test, to avoid side effects on other tests
- the value of "retvalshouldbe" for a successful test is 0, the value of a failed test is 1
- when a test is purposely failing, it should be marked as "noncompliant", when a test is checking a conform scenario, it should be marked as "resolved"
- when a test modifies configuration to create a non-compliant state, it must check if the configuration exists first; if not, skip the non-compliant test using "skip" with the register_test and run commands inside the conditional block
- a test should avoid using "mount", "remount" commands when running in a container ; if "mount" or "remount" commands are required, the test should be skipped when running in a container
- When the result output is not known, like on a blank system, use  "dismiss_count_for_test" 

## tools

- each script has to be validated by shellcheck and shellfmt
- each test has to be validated by shellcheck and shellfmt
