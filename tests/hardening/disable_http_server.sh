# shellcheck shell=bash
# run-shellcheck
test_audit() {
    local apache_available nginx_available
    apache_available=1
    nginx_available=1

    if apt-cache show apache2 2>/dev/null | grep -q '^Package: apache2$'; then
        apache_available=0
    fi
    if apt-cache show nginx 2>/dev/null | grep -q '^Package: nginx$'; then
        nginx_available=0
    fi

    if [ "$apache_available" -ne 0 ] && [ "$nginx_available" -ne 0 ]; then
        describe "apache2 and nginx packages are unavailable - skipping"
        skip
        register_test retvalshouldbe 0
        # shellcheck disable=2154
        run skipped "${CIS_CHECKS_DIR}/${script}.sh" --audit-all
        return
    fi

    if [ "$apache_available" -eq 0 ]; then
        describe "Prepare non-compliant state - install apache2"
        DEBIAN_FRONTEND=noninteractive apt-get install -y apache2 || true

        # Ensure we can actually create a non-compliant state.
        if "${CIS_CHECKS_DIR}/${script}.sh" --audit-all >/dev/null 2>&1; then
            if systemctl >/dev/null 2>&1; then
                systemctl unmask apache2.socket apache2.service >/dev/null 2>&1 || true
                systemctl enable apache2.socket apache2.service >/dev/null 2>&1 || true
                systemctl start apache2.socket apache2.service >/dev/null 2>&1 || true
            fi
        fi

        if "${CIS_CHECKS_DIR}/${script}.sh" --audit-all >/dev/null 2>&1; then
            describe "Unable to create a non-compliant apache2 state - skipping remediation path"
            skip
            register_test retvalshouldbe 0
            # shellcheck disable=2154
            run skipped_apache "${CIS_CHECKS_DIR}/${script}.sh" --audit-all
            describe "Cleanup apache2"
            apt-get purge -y apache2 || true
            apt-get autoremove -y || true
        else

            describe "Running failed test with apache2 installed"
            register_test retvalshouldbe 1
            # shellcheck disable=2154
            run failed_apache "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

            describe "Correcting apache2 state - enabling remediation"
            sed -i 's/audit/enabled/' "${CIS_CONF_DIR}/conf.d/${script}.cfg"
            "${CIS_CHECKS_DIR}/${script}.sh" --apply || true

            describe "Checking resolved apache2 state"
            register_test retvalshouldbe 0
            # shellcheck disable=2154
            run resolved_apache "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

            describe "Cleanup apache2"
            apt-get purge -y apache2 || true
            apt-get autoremove -y || true
        fi
    fi

    if [ "$nginx_available" -eq 0 ]; then
        describe "Prepare non-compliant state - install nginx"
        DEBIAN_FRONTEND=noninteractive apt-get install -y nginx || true

        # Ensure we can actually create a non-compliant state.
        if "${CIS_CHECKS_DIR}/${script}.sh" --audit-all >/dev/null 2>&1; then
            if systemctl >/dev/null 2>&1; then
                systemctl unmask nginx.service >/dev/null 2>&1 || true
                systemctl enable nginx.service >/dev/null 2>&1 || true
                systemctl start nginx.service >/dev/null 2>&1 || true
            fi
        fi

        if "${CIS_CHECKS_DIR}/${script}.sh" --audit-all >/dev/null 2>&1; then
            describe "Unable to create a non-compliant nginx state - skipping remediation path"
            skip
            register_test retvalshouldbe 0
            # shellcheck disable=2154
            run skipped_nginx "${CIS_CHECKS_DIR}/${script}.sh" --audit-all
            describe "Cleanup nginx"
            apt-get purge -y nginx || true
            apt-get autoremove -y || true
        else

            describe "Running failed test with nginx installed"
            register_test retvalshouldbe 1
            # shellcheck disable=2154
            run failed_nginx "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

            describe "Correcting nginx state - enabling remediation"
            sed -i 's/audit/enabled/' "${CIS_CONF_DIR}/conf.d/${script}.cfg"
            "${CIS_CHECKS_DIR}/${script}.sh" --apply || true

            describe "Checking resolved nginx state"
            register_test retvalshouldbe 0
            # shellcheck disable=2154
            run resolved_nginx "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

            describe "Cleanup nginx"
            apt-get purge -y nginx || true
            apt-get autoremove -y || true
        fi
    fi
}
