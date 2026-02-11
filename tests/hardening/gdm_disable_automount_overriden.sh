# shellcheck shell=bash
# run-shellcheck
test_audit() {

    describe Installing GDM
    DEBIAN_FRONTEND=noninteractive apt-get install -y gdm3 -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" || true

    describe Tests purposely failing
    rm -rf /etc/dconf/db/local.d/00-media-automount
    register_test retvalshouldbe 1
    register_test contain "automount setting not found"
    register_test contain "automount-open setting not found"
    # shellcheck disable=2154
    run noncompliant "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    describe Correcting situation
    sed -i 's/audit/enabled/' "${CIS_CONF_DIR}/conf.d/${script}.cfg"
    "${CIS_CHECKS_DIR}/${script}.sh" --apply || true

    describe Checking resolved state
    register_test retvalshouldbe 0
    register_test contain "automount setting found and set to false"
    register_test contain "automount-open setting found and set to false"
    # shellcheck disable=2154
    run resolved "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    describe Checking settings with spaces around equal sign
    mkdir -p /etc/dconf/db/local.d
    printf '[org/gnome/desktop/media-handling]\nautomount = false\nautomount-open = false\n' >/etc/dconf/db/local.d/00-media-automount
    register_test retvalshouldbe 0
    register_test contain "automount setting found and set to false"
    register_test contain "automount-open setting found and set to false"
    # shellcheck disable=2154
    run resolved "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    # Cleanup
    describe Removing test files
    rm -rf /etc/dconf/db/local.d/00-media-automount

    describe Removing GDM package
    DEBIAN_FRONTEND=noninteractive apt-get remove -y gdm3 || true
    DEBIAN_FRONTEND=noninteractive apt-get autoremove -y || true
}
