# shellcheck shell=bash
# run-shellcheck
test_audit() {
    describe Running on blank host
    register_test retvalshouldbe 1
    register_test contain "openssh-server is installed"
    # shellcheck disable=2154
    run blank "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    describe Correcting situation
    # `apply` performs a service reload after each change in the config file
    # the service needs to be started for the reload to succeed
    service ssh start
    # if the audit script provides "apply" option, enable and run it
    sed -i 's/audit/enabled/' "${CIS_CONF_DIR}/conf.d/${script}.cfg"
    "${CIS_CHECKS_DIR}/${script}.sh" || true

    describe Checking resolved state
    register_test retvalshouldbe 0
    register_test contain "^AllowUsers[[:space:]]** is present in /etc/ssh/sshd_config"
    register_test contain "^AllowGroups[[:space:]]** is present in /etc/ssh/sshd_config"
    register_test contain "^DenyUsers[[:space:]]*nobody is present in /etc/ssh/sshd_config"
    register_test contain "^DenyGroups[[:space:]]*nobody is present in /etc/ssh/sshd_config"
    run resolved "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    describe Check and report mismatch for allowed user
    useradd -s /bin/bash johnallow
    sed -i "s/ALLOWED_USERS=''/ALLOWED_USERS='johnallow'/" "${CIS_CONF_DIR}/conf.d/${script}.cfg"
    register_test retvalshouldbe 1
    register_test contain "^AllowUsers[[:space:]]*johnallow is not present in /etc/ssh/sshd_config"
    register_test contain "^AllowGroups[[:space:]]** is present in /etc/ssh/sshd_config"
    register_test contain "^DenyUsers[[:space:]]*nobody is present in /etc/ssh/sshd_config"
    register_test contain "^DenyGroups[[:space:]]*nobody is present in /etc/ssh/sshd_config"
    run allowed_user_mismatch "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    describe Correctly apply allowed user
    # the previous test checked that ALLOWED_USERS is set but not correctly applied in sshd_config so we apply it now
    "${CIS_CHECKS_DIR}/${script}.sh" || true
    # and check again that the fix was correctly applied
    register_test retvalshouldbe 0
    register_test contain "^AllowUsers[[:space:]]*johnallow is present in /etc/ssh/sshd_config"
    register_test contain "^AllowGroups[[:space:]]** is present in /etc/ssh/sshd_config"
    register_test contain "^DenyUsers[[:space:]]*nobody is present in /etc/ssh/sshd_config"
    register_test contain "^DenyGroups[[:space:]]*nobody is present in /etc/ssh/sshd_config"
    run fix_user_mismatch "${CIS_CHECKS_DIR}/${script}.sh" --apply-all

    describe Check and report mismatch for multiple allowed users
    useradd -s /bin/bash janeallow
    sed -i "s/johnallow/johnallow janeallow/" "${CIS_CONF_DIR}/conf.d/${script}.cfg"
    register_test retvalshouldbe 1
    register_test contain "^AllowUsers[[:space:]]*johnallow janeallow is not present in /etc/ssh/sshd_config"
    register_test contain "^AllowGroups[[:space:]]** is present in /etc/ssh/sshd_config"
    register_test contain "^DenyUsers[[:space:]]*nobody is present in /etc/ssh/sshd_config"
    register_test contain "^DenyGroups[[:space:]]*nobody is present in /etc/ssh/sshd_config"
    run multi_allowed_user_mismatch "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    describe Correctly apply multiple allowed users
    # the previous test checked that ALLOWED_USERS is set but not correctly applied in sshd_config so we apply it now
    "${CIS_CHECKS_DIR}/${script}.sh" || true
    # and check again that the fix was correctly applied
    tail -n 5 /etc/ssh/sshd_config
    register_test retvalshouldbe 0
    register_test contain "^AllowUsers[[:space:]]*johnallow janeallow is present in /etc/ssh/sshd_config"
    register_test contain "^AllowGroups[[:space:]]** is present in /etc/ssh/sshd_config"
    register_test contain "^DenyUsers[[:space:]]*nobody is present in /etc/ssh/sshd_config"
    register_test contain "^DenyGroups[[:space:]]*nobody is present in /etc/ssh/sshd_config"
    run fix_multi_allowed_user_mismatch "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    # reset allowed users to default before continuing
    sed -i "s/ALLOWED_USERS='johnallow janeallow'/ALLOWED_USERS=''/" "${CIS_CONF_DIR}/conf.d/${script}.cfg"

    describe Check and report mismatch for denied user
    useradd -s /bin/bash peterdeny
    sed -i "s/DENIED_USERS=''/DENIED_USERS='peterdeny'/" "${CIS_CONF_DIR}/conf.d/${script}.cfg"
    register_test retvalshouldbe 1
    register_test contain "^AllowUsers[[:space:]]** is present in /etc/ssh/sshd_config"
    register_test contain "^AllowGroups[[:space:]]** is present in /etc/ssh/sshd_config"
    register_test contain "^DenyUsers[[:space:]]*peterdeny is not present in /etc/ssh/sshd_config"
    register_test contain "^DenyGroups[[:space:]]*nobody is present in /etc/ssh/sshd_config"
    run denied_user_mismatch "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    describe Correctly apply denied user
    # the previous test checked that DENIED_USERS is set but not correctly applied in sshd_config so we apply it now
    "${CIS_CHECKS_DIR}/${script}.sh" || true
    # and check again that the fix was correctly applied
    register_test retvalshouldbe 0
    register_test contain "^AllowUsers[[:space:]]** is present in /etc/ssh/sshd_config"
    register_test contain "^AllowGroups[[:space:]]** is present in /etc/ssh/sshd_config"
    register_test contain "^DenyUsers[[:space:]]*peterdeny is present in /etc/ssh/sshd_config"
    register_test contain "^DenyGroups[[:space:]]*nobody is present in /etc/ssh/sshd_config"
    run fix_denied_user_mismatch "${CIS_CHECKS_DIR}/${script}.sh" --apply-all

    describe Check and report mismatch for multiple denied users
    useradd -s /bin/bash marrydeny
    sed -i "s/peterdeny/peterdeny marrydeny/" "${CIS_CONF_DIR}/conf.d/${script}.cfg"
    register_test retvalshouldbe 1
    register_test contain "^AllowUsers[[:space:]]** is present in /etc/ssh/sshd_config"
    register_test contain "^AllowGroups[[:space:]]** is present in /etc/ssh/sshd_config"
    register_test contain "^DenyUsers[[:space:]]*peterdeny marrydeny is not present in /etc/ssh/sshd_config"
    register_test contain "^DenyGroups[[:space:]]*nobody is present in /etc/ssh/sshd_config"
    run multi_denied_user_mismatch "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    describe Correctly apply multiple denied users
    # the previous test checked that DENIED_USERS is set but not correctly applied in sshd_config so we apply it now
    "${CIS_CHECKS_DIR}/${script}.sh" || true
    # and check again that the fix was correctly applied
    register_test retvalshouldbe 0
    register_test contain "^AllowUsers[[:space:]]** is present in /etc/ssh/sshd_config"
    register_test contain "^AllowGroups[[:space:]]** is present in /etc/ssh/sshd_config"
    register_test contain "^DenyUsers[[:space:]]*peterdeny marrydeny is present in /etc/ssh/sshd_config"
    register_test contain "^DenyGroups[[:space:]]*nobody is present in /etc/ssh/sshd_config"
    run fix_multi_denied_user_mismatch "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    # reset to prevent other test from possibly failing in the future
    sed -i "s/DENIED_USERS='peterdeny marrydeny'/DENIED_USERS=''/" "${CIS_CONF_DIR}/conf.d/${script}.cfg"
    "${CIS_CHECKS_DIR}/${script}.sh" || true
    describe Checking resolved state
    register_test retvalshouldbe 0
    register_test contain "^AllowUsers[[:space:]]** is present in /etc/ssh/sshd_config"
    register_test contain "^AllowGroups[[:space:]]** is present in /etc/ssh/sshd_config"
    register_test contain "^DenyUsers[[:space:]]*nobody is present in /etc/ssh/sshd_config"
    register_test contain "^DenyGroups[[:space:]]*nobody is present in /etc/ssh/sshd_config"
    run cleanup_resolved "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    # Cleanup
    userdel johnallow
    userdel janeallow
    userdel peterdeny
    userdel marrydeny
}
