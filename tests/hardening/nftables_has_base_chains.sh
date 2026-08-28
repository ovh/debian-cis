# shellcheck shell=bash
# run-shellcheck
test_audit() {
    describe Prepare test
    apt install -y nftables

    # running on a non privilieged container, wont test much...
    describe Running on blank host
    register_test retvalshouldbe 1
    # shellcheck disable=2154
    run blank "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    # Reading and writing a ruleset needs CAP_NET_ADMIN, which the test
    # container does not always have.
    if nft list ruleset >/dev/null 2>&1; then
        # A base chain in the bridge family filters no IP traffic, so it must
        # not be taken for the base chain the recommendation asks for.
        if nft add table bridge cis_test &&
            nft add chain bridge cis_test input '{ type filter hook input priority 0 ; }' &&
            nft add chain bridge cis_test output '{ type filter hook output priority 0 ; }' &&
            nft add chain bridge cis_test forward '{ type filter hook forward priority 0 ; }'; then
            describe Running with bridge base chains and no IP one
            register_test retvalshouldbe 1
            register_test contain "does not exist"
            # shellcheck disable=2154
            run bridgeonly "${CIS_CHECKS_DIR}/${script}.sh" --audit-all
        else
            skip "cannot create a bridge table, skipping the bridge family check"
        fi

        if nft add table inet cis_test &&
            nft add chain inet cis_test input '{ type filter hook input priority 0 ; }' &&
            nft add chain inet cis_test output '{ type filter hook output priority 0 ; }' &&
            nft add chain inet cis_test forward '{ type filter hook forward priority 0 ; }'; then
            describe Running with IP base chains
            register_test retvalshouldbe 0
            # shellcheck disable=2154
            run ipchains "${CIS_CHECKS_DIR}/${script}.sh" --audit-all
        else
            skip "cannot create an inet table, skipping the compliant case"
        fi

        describe Removing the test ruleset
        nft delete table bridge cis_test >/dev/null 2>&1 || true
        nft delete table inet cis_test >/dev/null 2>&1 || true
    else
        skip "no netfilter access in this environment, skipping ruleset checks"
    fi

    describe clean test
    apt remove -y nftables
}
