# shellcheck shell=bash
# run-shellcheck
test_audit() {
    describe Running on blank host
    register_test retvalshouldbe 0
    dismiss_count_for_test
    # shellcheck disable=2154
    run blank "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    ##################################################################
    # For this test, we only check that it runs properly on a blank  #
    # host, and we check root/sudo consistency. But, we don't test   #
    # the apply function because it can't be automated or it is very #
    # long to test and not very useful.                              #
    ##################################################################

    # add_option_to_fstab() is shared by every <partition>_<option> script, so
    # it is tested here rather than in each of them. It is exercised against a
    # fixture /etc/fstab holding the two entry shapes it has to handle: a
    # single filesystem type, and a multi-value one, where the option must
    # still land in the options field and not in the type field.
    describe Adding an option to fstab
    cp -a /etc/fstab /tmp/fstab.orig
    cat >/etc/fstab <<'FSTAB'
/dev/sda9   /var           ext4         defaults,errors=remount-ro  0  2
/dev/cdrom  /media/cdrom0  udf,iso9660  user,noauto                 0  0
FSTAB
    bash -c '
        set +u
        . /etc/default/cis-hardening
        . "${CIS_CONF_DIR}"/hardening.cfg
        . "${CIS_LIB_DIR}"/common.sh
        . "${CIS_LIB_DIR}"/utils.sh
        mkdir -p "$BACKUPDIR"
        add_option_to_fstab "/var" "nodev"
        add_option_to_fstab "/media\S*" "noexec"
        # a second apply must not append the option twice
        add_option_to_fstab "/var" "nodev"
    ' >/dev/null 2>&1
    # publish the outcome where the sudo run can read it too
    {
        cat /etc/fstab
        # `sed -ie` would have left a stale copy of fstab next to it
        strays=$(find /etc -maxdepth 1 -name 'fstab?*' -printf '%f ')
        echo "stray fstab copies: ${strays:-none}"
    } >/tmp/fstab.result
    chmod 644 /tmp/fstab.result
    mv /tmp/fstab.orig /etc/fstab

    register_test retvalshouldbe 0
    register_test contain REGEX '^/dev/sda9\s+/var\s+ext4\s+defaults,errors=remount-ro,nodev\s+0\s+2$'
    register_test contain REGEX '^/dev/cdrom\s+/media/cdrom0\s+udf,iso9660\s+user,noauto,noexec\s+0\s+0$'
    register_test contain stray fstab copies: none
    # the trailing '#' comments out the --sudo that run() appends
    run fstab_option "cat /tmp/fstab.result #"
}
