# shellcheck shell=bash
# run-shellcheck
test_audit() {
    tmpdir=$(mktemp -d)
    backup_profile=0
    backup_bashrc=0
    backup_profiled=0

    if [ -f /etc/profile ]; then
        cp /etc/profile "$tmpdir/profile.bak"
        backup_profile=1
    fi
    if [ -f /etc/bash.bashrc ]; then
        cp /etc/bash.bashrc "$tmpdir/bash.bashrc.bak"
        backup_bashrc=1
    fi
    if [ -d /etc/profile.d ]; then
        cp -a /etc/profile.d "$tmpdir/profile.d.bak"
        backup_profiled=1
    fi

    rm -rf /etc/profile.d
    mkdir -p /etc/profile.d

    cat <<'EOF' >/etc/profile
# default_timeout test fixture
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
EOF
    cat <<'EOF' >/etc/bash.bashrc
# default_timeout test fixture
EOF

    describe no TMOUT configured anywhere
    register_test retvalshouldbe 1
    # shellcheck disable=2154
    run noncompliant_none "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    describe apply adds TMOUT when absent
    # shellcheck disable=2154
    sed -i 's/audit/enabled/' "${CIS_CONF_DIR}/conf.d/${script}.cfg"
    # shellcheck disable=2154
    "${CIS_CHECKS_DIR}/${script}.sh" --apply || true

    describe resolved after apply
    register_test retvalshouldbe 0
    # shellcheck disable=2154
    run resolved_apply "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    rm -f /etc/profile.d/CIS_99.1_timeout.sh
    cat <<'EOF' >/etc/profile
# default_timeout test fixture
TMOUT=500
export TMOUT
EOF
    cat <<'EOF' >/etc/bash.bashrc
# default_timeout test fixture
EOF

    describe TMOUT found in /etc/profile
    register_test retvalshouldbe 0
    # shellcheck disable=2154
    run present_profile "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    cat <<'EOF' >/etc/profile
# default_timeout test fixture
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
EOF
    cat <<'EOF' >/etc/bash.bashrc
# default_timeout test fixture
TMOUT=550
export TMOUT
EOF

    describe TMOUT found in /etc/bash.bashrc
    register_test retvalshouldbe 0
    # shellcheck disable=2154
    run present_bashrc "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    cat <<'EOF' >/etc/profile
# default_timeout test fixture
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
EOF
    cat <<'EOF' >/etc/bash.bashrc
# default_timeout test fixture
EOF
    cat <<'EOF' >/etc/profile.d/custom_timeout.sh
TMOUT=450
export TMOUT
EOF

    describe TMOUT found in /etc/profile.d
    register_test retvalshouldbe 0
    # shellcheck disable=2154
    run present_profiled "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    rm -rf /etc/profile.d
    if [ "$backup_profiled" -eq 1 ]; then
        cp -a "$tmpdir/profile.d.bak" /etc/profile.d
    else
        mkdir -p /etc/profile.d
    fi

    if [ "$backup_profile" -eq 1 ]; then
        cp "$tmpdir/profile.bak" /etc/profile
    else
        rm -f /etc/profile
    fi

    if [ "$backup_bashrc" -eq 1 ]; then
        cp "$tmpdir/bash.bashrc.bak" /etc/bash.bashrc
    else
        rm -f /etc/bash.bashrc
    fi

    rm -rf "$tmpdir"
}
