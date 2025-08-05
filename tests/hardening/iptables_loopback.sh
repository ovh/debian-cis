# shellcheck shell=bash
# run-shellcheck
test_audit() {
    # to test this check, we need to detect the debian version
    # this function is available in lib/utils.sh, but not usable currently in the tests
    # we have to source lib/mains.sh to use it, which we can't currently
    echo "There is no meaningful test available at the moment"
}
