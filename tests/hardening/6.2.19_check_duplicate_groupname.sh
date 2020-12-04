# shellcheck shell=bash
# run-shellcheck
test_audit() {
    describe Running on blank host
    register_test retvalshouldbe 0
    dismiss_count_for_test
    # shellcheck disable=2154
    run blank /opt/debian-cis/bin/hardening/"${script}".sh --audit-all

    local test_group="testduplicategroup"
    local dir="/etc/group"

    describe Tests purposely failing
    useradd "$test_group"
    temp=$(tail -1 "$dir")
    echo "$temp" >>"$dir"
    register_test retvalshouldbe 1
    register_test contain "Duplicate group"
    run noncompliant /opt/debian-cis/bin/hardening/"${script}".sh --audit-all

    # cleanup
    sed -i '$ d' "$dir"
    userdel "$test_group"
}
