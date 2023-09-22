# shellcheck shell=bash
# run-shellcheck
test_audit() {
    # shellcheck disable=2154
    run blank "${CIS_CHECKS_DIR}/${script}.sh" --audit-all
    # shellcheck disable=2016
    echo 'EXCEPT="$EXCEPT debian"' >>"${CIS_CONF_DIR}/conf.d/${script}.cfg"

    describe Running on blank host
    register_test retvalshouldbe 0
    dismiss_count_for_test
    register_test contain "There is no carte-blanche sudo permission in"
    # shellcheck disable=2154
    run blank "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    # Proceed to operation that will end up to a non compliant system
    useradd -s /bin/bash jeantestuser
    echo 'jeantestuser ALL = (ALL) NOPASSWD:ALL' >>/etc/sudoers.d/jeantestuser
    describe Fail: Not compliant system
    register_test retvalshouldbe 1
    register_test contain "[ KO ] jeantestuser ALL = (ALL) NOPASSWD:ALL is present in /etc/sudoers.d/jeantestuser"
    run userallcmd "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    # shellcheck disable=2016
    echo 'EXCEPT="$EXCEPT debian jeantestuser"' >>"${CIS_CONF_DIR}/conf.d/${script}.cfg"
    describe Adding jeantestuser to exceptions
    register_test retvalshouldbe 0
    register_test contain "[ OK ] jeantestuser ALL = (ALL) NOPASSWD:ALL is present in /etc/sudoers.d/jeantestuser but was EXCUSED because jeantestuser is part of exceptions"
    run userexcept "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    rm -f /etc/sudoers.d/jeantestuser
    userdel jeantestuser
}
