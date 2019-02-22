# run-shellcheck
test_audit() {
    describe Running on blank host
    register_test retvalshouldbe 1
    dismiss_count_for_test
    # shellcheck disable=2154
    run blank /opt/debian-cis/bin/hardening/"${script}".sh --audit-all

    ln -s /dev/shm /run/shm

    describe Partition symlink
    register_test retvalshouldbe 1
    register_test contain "[WARN] /run/shm actually is /dev/shm"
    run resolved /opt/debian-cis/bin/hardening/"${script}".sh --audit-all

    # TODO fill comprehensive tests
}
