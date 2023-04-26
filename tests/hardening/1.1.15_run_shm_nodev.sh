# shellcheck shell=bash
# run-shellcheck
test_audit() {
    describe Running on blank host
    register_test retvalshouldbe 0
    # shellcheck disable=2154
    run blank /opt/debian-cis/bin/hardening/"${script}".sh --audit-all

    ln -s /dev/shm /run/shm

    describe Partition symlink
    register_test retvalshouldbe 0
    run resolved /opt/debian-cis/bin/hardening/"${script}".sh --audit-all

    echo "dummy entry" >>/etc/fstab

    describe Fstab with a real entry to match runtime partitions
    register_test retvalshouldbe 0
    run resolved /opt/debian-cis/bin/hardening/"${script}".sh --audit-all

    # Cleanup
    rm /run/shm
    sed "/dummy entry/d" /etc/fstab

    ##################################################################
    # For this test, we only check that it runs properly on a blank  #
    # host, and we check root/sudo consistency. But, we don't test   #
    # the apply function because it can't be automated or it is very #
    # long to test and not very useful.                              #
    ##################################################################
}
