# shellcheck shell=bash
# run-shellcheck
test_audit() {
    describe Running on blank host
    register_test retvalshouldbe 1
    # shellcheck disable=2154
    run blank "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    describe "Installing nftables for tests"
    apt-get update >/dev/null 2>&1 || true
    DEBIAN_FRONTEND='noninteractive' apt-get install -y nftables >/dev/null 2>&1 || {
        skip "Cannot install nftables, skipping tests"
        return
    }

    # Reading and writing a ruleset needs CAP_NET_ADMIN, which the test
    # container does not always have.
    if nft list ruleset >/dev/null 2>&1; then
        # Chain the setup commands so that a partial ruleset never reaches the
        # assertions, and delete the tables on every path out: the rest of the
        # suite runs in this very container, with no rule accepting established
        # traffic.
        if nft add table inet cis_test &&
            nft add chain inet cis_test input '{ type filter hook input priority 0 ; policy accept ; }' &&
            nft add chain inet cis_test forward '{ type filter hook forward priority 0 ; policy accept ; }'; then

            describe Creating a permissive nftables ruleset
            register_test retvalshouldbe 1
            register_test contain "should be DROP"
            # shellcheck disable=2154
            run nftaccept "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

            # The bridge family reuses the input and forward hook names for a
            # packet path that carries no routed nor locally delivered IP
            # traffic, so its policy must not be taken for an IP one.
            describe Adding a bridge ruleset set to drop, IP traffic still unfiltered
            if nft add table bridge cis_test &&
                nft add chain bridge cis_test input '{ type filter hook input priority 0 ; policy drop ; }' &&
                nft add chain bridge cis_test forward '{ type filter hook forward priority 0 ; policy drop ; }'; then
                register_test retvalshouldbe 1
                register_test contain "should be DROP"
                # shellcheck disable=2154
                run nftbridge "${CIS_CHECKS_DIR}/${script}.sh" --audit-all
            else
                skip "cannot create a bridge table, skipping the bridge family check"
            fi

            describe Setting the nftables default policy to drop
            if nft chain inet cis_test input '{ policy drop ; }' &&
                nft chain inet cis_test forward '{ policy drop ; }'; then
                register_test retvalshouldbe 0
                register_test contain "nftables"
                # shellcheck disable=2154
                run nftdrop "${CIS_CHECKS_DIR}/${script}.sh" --audit-all
            else
                skip "cannot set the default policy to drop, skipping"
            fi
        else
            skip "cannot create the test ruleset, skipping ruleset checks"
        fi

        describe Removing the test ruleset
        nft delete table inet cis_test >/dev/null 2>&1 || true
        nft delete table bridge cis_test >/dev/null 2>&1 || true
    else
        skip "no netfilter access in this environment, skipping ruleset checks"
    fi

    describe Cleaning up
    apt-get remove -y nftables >/dev/null 2>&1 || true
    apt-get autoremove -y >/dev/null 2>&1 || true
}
