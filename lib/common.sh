# CIS Debian 7 Hardening common functions

logger() {
    test -z "$SCRIPT_NAME" && SCRIPT_NAME=$(basename $0)
    logger -i -t "$SCRIPT_NAME" -p "user.info" "$(date +%Y.%m.%d-%H:%M:%S) $*"
    test -t 1 && echo "$(date +%Z-%Y.%m.%d-%H:%M:%S) $*"
}
