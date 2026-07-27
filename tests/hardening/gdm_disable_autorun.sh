# shellcheck shell=bash
# run-shellcheck
test_audit() {

    describe Installing GDM
    DEBIAN_FRONTEND=noninteractive apt-get install -y gdm3 -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" || true

    describe Tests purposely failing
    # Remove any existing configuration
    rm -rf /etc/dconf/db/local.d/00-media-autorun
    rm -rf /etc/dconf/db/local
    rm -f /etc/dconf/profile/user
    register_test retvalshouldbe 1
    register_test contain "autorun-never is not set"
    # shellcheck disable=2154
    run noncompliant "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    describe Correcting situation
    sed -i 's/audit/enabled/' "${CIS_CONF_DIR}/conf.d/${script}.cfg"
    "${CIS_CHECKS_DIR}/${script}.sh" --apply || true

    describe Checking resolved state
    register_test retvalshouldbe 0
    register_test contain "autorun-never is set to true"
    register_test contain "dconf database profile file"
    register_test contain "The dconf database local exists"
    register_test contain "The dconf directory"
    # shellcheck disable=2154
    run resolved "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    # Cleanup
    describe Removing test files
    rm -rf /etc/dconf/db/local.d/00-media-autorun
    rm -rf /etc/dconf/db/local
    rm -f /etc/dconf/profile/user

    describe Removing GDM package
    DEBIAN_FRONTEND=noninteractive apt-get remove -y gdm3 || true
    DEBIAN_FRONTEND=noninteractive apt-get autoremove -y || true
}
