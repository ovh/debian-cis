# shellcheck shell=bash
# run-shellcheck
test_audit() {
    # Determine which GDM package and config dir to use
    local gdm_pkg gdm_conf_dir
    if dpkg -s gdm3 >/dev/null 2>&1; then
        gdm_pkg="gdm3"
        gdm_conf_dir="/etc/gdm3"
    else
        gdm_pkg="gdm"
        gdm_conf_dir="/etc/gdm"
    fi

    describe "Installing GDM ($gdm_pkg)"
    DEBIAN_FRONTEND=noninteractive apt-get install -y "$gdm_pkg" -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" || true

    describe Tests purposely failing - enabling XDMCP
    # Add XDMCP enable to config
    if [ -f "$gdm_conf_dir/custom.conf" ]; then
        echo -e "\n[xdmcp]\nEnable=true" >>"$gdm_conf_dir/custom.conf"
    elif [ -f "$gdm_conf_dir/daemon.conf" ]; then
        echo -e "\n[xdmcp]\nEnable=true" >>"$gdm_conf_dir/daemon.conf"
    fi
    register_test retvalshouldbe 1
    register_test contain "XDMCP is enabled"
    # shellcheck disable=2154
    run noncompliant "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    describe Correcting situation
    sed -i 's/audit/enabled/' "${CIS_CONF_DIR}/conf.d/${script}.cfg"
    "${CIS_CHECKS_DIR}/${script}.sh" --apply || true

    describe Checking resolved state
    register_test retvalshouldbe 0
    register_test contain "not enabled"
    # shellcheck disable=2154
    run resolved "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    describe Cleanup
    # Restore original config files
    if [ -f "$gdm_conf_dir/custom.conf" ]; then
        sed -i '/^\[xdmcp\]/,/^Enable=true/d' "$gdm_conf_dir/custom.conf"
        sed -i '/#Enable=true/d' "$gdm_conf_dir/custom.conf"
    fi
    if [ -f "$gdm_conf_dir/daemon.conf" ]; then
        sed -i '/^\[xdmcp\]/,/^Enable=true/d' "$gdm_conf_dir/daemon.conf"
        sed -i '/#Enable=true/d' "$gdm_conf_dir/daemon.conf"
    fi

    # Remove package and dependencies
    apt-get remove -y "$gdm_pkg" || true
    apt-get autoremove -y || true

}
