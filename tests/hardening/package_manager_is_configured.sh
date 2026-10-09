# shellcheck shell=bash
# run-shellcheck
test_audit() {
    local fixture
    fixture=$(mktemp -d)
    chmod 755 "$fixture"
    install -d -m 755 "$fixture/etc/parts" "$fixture/etc/conf.d" "$fixture/lists"
    cat >"$fixture/apt.conf" <<CONF
Dir::Etc "$fixture/etc";
Dir::Etc::sourcelist "sources.list";
Dir::Etc::sourceparts "parts";
Dir::Etc::main "apt.conf";
Dir::Etc::parts "conf.d";
Dir::State::lists "$fixture/lists";
APT::Architecture "amd64";
CONF
    chmod 644 "$fixture/apt.conf"

    describe Checking missing repository configuration
    register_test retvalshouldbe 1
    # shellcheck disable=2154
    run no_sources env "APT_CONFIG=$fixture/apt.conf" "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    # Cached metadata alone must not be mistaken for configured repositories.
    touch "$fixture/lists/old_Packages"
    chmod 644 "$fixture/lists/old_Packages"
    describe Checking stale cache without configured repositories
    register_test retvalshouldbe 1
    run stale_cache env "APT_CONFIG=$fixture/apt.conf" "${CIS_CHECKS_DIR}/${script}.sh" --audit-all
    rm -f "$fixture/lists/old_Packages"

    echo 'deb https://example.invalid/debian trixie main' >"$fixture/etc/sources.list"
    chmod 644 "$fixture/etc/sources.list"
    describe Checking a configured sources.list repository
    register_test retvalshouldbe 0
    run list_source env "APT_CONFIG=$fixture/apt.conf" "${CIS_CHECKS_DIR}/${script}.sh" --audit-all
    rm -f "$fixture/etc/sources.list"

    printf 'Types: deb\nURIs: https://example.invalid/debian\nSuites: trixie\nComponents: main\n' >"$fixture/etc/parts/debian.sources"
    chmod 644 "$fixture/etc/parts/debian.sources"
    describe Checking a configured deb822 repository
    register_test retvalshouldbe 0
    run deb822_source env "APT_CONFIG=$fixture/apt.conf" "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    printf 'Types: deb\nURIs: https://example.invalid/debian\nSuites: trixie\nComponents: main\nEnabled: no\n' >"$fixture/etc/parts/debian.sources"
    describe Checking a disabled deb822 repository
    register_test retvalshouldbe 1
    run disabled_source env "APT_CONFIG=$fixture/apt.conf" "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    rm -rf -- "$fixture"
}
