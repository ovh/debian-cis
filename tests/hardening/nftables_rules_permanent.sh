# shellcheck shell=bash
# run-shellcheck
test_audit() {
    describe prepare failing test
    rm -f /etc/nftables.conf
    touch /etc/nftables.conf
    touch /etc/nftables.rules

    describe Running failed 'missing include'
    register_test retvalshouldbe 1
    # shellcheck disable=2154
    run failed "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    describe Fixing first situation
    sed -i 's/audit/enabled/' "${CIS_CONF_DIR}/conf.d/${script}.cfg"
    "${CIS_CHECKS_DIR}/${script}.sh" || true

    # the 'include' part is fixed, but configuration is missing
    # this has to be fixed manually, so for now, sill a failing test
    describe Running failed 'missing basic chains'
    register_test retvalshouldbe 1
    run failed "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    # Base chains of the bridge family filter no IP traffic, so persisting
    # them is not what the recommendation asks for.
    describe Running failed 'only bridge chains persisted'
    cat >/etc/nftables.rules <<'EOF'
table bridge cis_test {
	chain input {
		type filter hook input priority 0;
	}
	chain output {
		type filter hook output priority 0;
	}
	chain forward {
		type filter hook forward priority 0;
	}
}
EOF
    register_test retvalshouldbe 1
    run failed "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    describe Fixing final situation
    cat >/etc/nftables.rules <<'EOF'
table inet cis_test {
	chain input {
		type filter hook input priority 0;
		tcp dport { 22, 80 } accept
	}
	chain output {
		type filter hook output priority 0;
	}
	chain forward {
		type filter hook forward priority 0;
	}
}
EOF

    describe Running success
    register_test retvalshouldbe 0
    run success "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    describe clean test
    rm -f /etc/nftables.conf /etc/nftables.rules

}
