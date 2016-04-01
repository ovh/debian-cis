# CIS Debian 7 Hardening common functions

logger() {
    test -z "$SCRIPT_NAME" && SCRIPT_NAME=$(basename $0)
    /usr/bin/logger -i -t "$SCRIPT_NAME" -p "user.info" "$*"
    test -t 1 && echo "$*"
}
