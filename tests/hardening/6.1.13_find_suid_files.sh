# shellcheck shell=bash
# run-shellcheck
test_audit() {
    describe Running void to generate the conf file that will later be edited
    # shellcheck disable=2154
    /opt/debian-cis/bin/hardening/"${script}".sh || true
    # shellcheck disable=2016
    echo 'EXCEPTIONS="$EXCEPTIONS /usr/lib/dbus-1.0/dbus-daemon-launch-helper /usr/sbin/exim4 /bin/fusermount /usr/lib/eject/dmcrypt-get-device /usr/bin/pkexec /usr/lib/policykit-1/polkit-agent-helper-1"' >>/opt/debian-cis/etc/conf.d/"${script}".cfg

    describe Running on blank host
    register_test retvalshouldbe 0
    dismiss_count_for_test
    run blank /opt/debian-cis/bin/hardening/"${script}".sh --audit-all

    describe Tests purposely failing
    local targetfile="/home/secaudit/suid_file"
    touch "$targetfile"
    chmod 4700 "$targetfile"
    register_test retvalshouldbe 1
    register_test contain "Some suid files are present"
    register_test contain "$targetfile"
    run noncompliant /opt/debian-cis/bin/hardening/"${script}".sh --audit-all

    describe Tests failing with find ignore flag
    echo 'FIND_IGNORE_NOSUCHFILE_ERR=true' >>/opt/debian-cis/etc/conf.d/"${script}".cfg
    register_test retvalshouldbe 1
    register_test contain "Some suid files are present"
    run noncompliant /opt/debian-cis/bin/hardening/"${script}".sh --audit-all

    describe correcting situation
    chmod 700 $targetfile

    describe Checking resolved state
    register_test retvalshouldbe 0
    register_test contain "No unknown suid files found"
    run resolved /opt/debian-cis/bin/hardening/"${script}".sh --audit-all
}
