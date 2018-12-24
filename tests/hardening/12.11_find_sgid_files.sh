test_audit() {
    describe Running on blank host
    register_test retvalshouldbe 0
    register_test contain "No unknown sgid files found"
    # shellcheck disable=2154
    run blank /opt/debian-cis/bin/hardening/"${script}".sh --audit-all

    describe Tests purposely failing
    local targetfile="/home/secaudit/sgid_file"
    touch $targetfile
    chmod 2700 $targetfile
    register_test retvalshouldbe 1
    register_test contain "Some sgid files are present"
    register_test contain "$targetfile"
    run noncompliant /opt/debian-cis/bin/hardening/"${script}".sh --audit-all

    describe correcting situation
    chmod 700 $targetfile

    describe Checking resolved state
    register_test retvalshouldbe 0
    register_test contain "No unknown sgid files found"
    run resolved /opt/debian-cis/bin/hardening/"${script}".sh --audit-all
}

