# shellcheck shell=bash
# run-shellcheck
test_audit() {
    for file in /etc/security/opasswd /etc/security/opasswd.old; do
        if [ -e "$file" ]; then

            describe prepare failing test
            chmod 644 "$file"

            describe On purpose failing test
            register_test retvalshouldbe 1
            # shellcheck disable=2154
            run failed "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

            describe correcting situation
            sed -i 's/audit/enabled/' "${CIS_CONF_DIR}/conf.d/${script}.cfg"
            "${CIS_CHECKS_DIR}/${script}.sh" --apply || true

            describe resolved test
            register_test retvalshouldbe 0
            run resolved "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

            describe ensure more restrictive is allowed
            chmod 400 "$file"

            describe successful test
            register_test retvalshouldbe 0
            run successful "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

            describe failling at uid
            chown 500 "$file"

            describe On purpose failing test
            register_test retvalshouldbe 1
            # shellcheck disable=2154
            run failed "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

            describe correcting situation
            "${CIS_CHECKS_DIR}/${script}.sh" --apply || true

            describe resolved test
            register_test retvalshouldbe 0
            run resolved "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

            describe failling at gid
            chown 500 "$file"

            describe On purpose failing test
            register_test retvalshouldbe 1
            # shellcheck disable=2154
            run failed "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

            describe correcting situation
            "${CIS_CHECKS_DIR}/${script}.sh" --apply || true

            describe resolved test
            register_test retvalshouldbe 0
            run resolved "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

        fi

    done
}
