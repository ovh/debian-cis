# shellcheck shell=bash
# run-shellcheck
test_audit() {
    describe Running on blank host
    register_test retvalshouldbe 0
    register_test contain "All world writable directories have a sticky bit"
    # shellcheck disable=2154
    run blank /opt/debian-cis/bin/hardening/"${script}".sh --audit-all
    if [ -f "/.dockerenv" ]; then
        skip "SKIPPED on docker"
    else
        describe Tests purposely failing
        local targetdir="/home/secaudit/world_writable_folder"
        mkdir $targetdir || true
        chmod 777 "$targetdir"
        register_test retvalshouldbe 1
        register_test contain "Some world writable directories are not on sticky bit mode"
        run noncompliant /opt/debian-cis/bin/hardening/"${script}".sh --audit-all

        describe correcting situation
        sed -i 's/audit/enabled/' /opt/debian-cis/etc/conf.d/"${script}".cfg
        /opt/debian-cis/bin/hardening/"${script}".sh --apply || true

        describe Checking resolved state
        register_test retvalshouldbe 0
        register_test contain "All world writable directories have a sticky bit"
        run resolved /opt/debian-cis/bin/hardening/"${script}".sh --audit-all
    fi
}
