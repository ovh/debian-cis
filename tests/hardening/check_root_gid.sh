# shellcheck shell=bash
# run-shellcheck
test_audit() {
    describe Tests purposely failing
    # Create a test group with GID 0
    groupadd -g 0 -o testgroup_gid0 || true
    register_test retvalshouldbe 1
    register_test contain "have GID 0"
    # shellcheck disable=2154
    run noncompliant "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    describe Manual remediation required
    # This recommendation requires manual intervention
    # The script cannot automatically fix this as it requires human decision
    # We'll manually delete the test group
    groupdel testgroup_gid0 || true

    describe Checking resolved state
    register_test retvalshouldbe 0
    register_test contain "Only root group has GID 0"
    run resolved "${CIS_CHECKS_DIR}/${script}.sh" --audit-all
}
