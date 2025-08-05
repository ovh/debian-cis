tests_is_ipv6_enabled() {
    CURRENT_IPV6_ENABLED=1
    if sysctl net.ipv6 >/dev/null 2>&1; then
        for iface in /proc/sys/net/ipv6/conf/*; do
            ifname=$(basename "$iface")
            if [ "$ifname" != "default" ] && [ "$ifname" != "all" ]; then
                value=$(cat "$iface"/disable_ipv6)
                # if only one interface has ipv6, this is enough to consider it enabled
                if [ "$value" -eq 0 ]; then
                    CURRENT_IPV6_ENABLED=0
                    break
                fi
            fi
        done
    fi
}

tests_get_debian_major_version() {
    DEB_MAJ_VER=""
    if [ -e /etc/debian_version ]; then
        DEB_MAJ_VER=$(cut -d '.' -f1 /etc/debian_version)
    else
        # shellcheck disable=2034
        DEB_MAJ_VER=$(lsb_release -r | cut -f2 | cut -d '.' -f 1)
    fi
}
