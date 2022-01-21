# shellcheck shell=bash
# CIS Debian Hardening common functions

# run-shellcheck
#
# File Backup functions
#
backup_file() {
    FILE=$1
    if [ ! -f "$FILE" ]; then
        crit "Cannot backup $FILE, it's not a file"
        FNRET=1
    else
        TARGET=$(echo "$FILE" | sed -s -e 's/\//./g' -e 's/^.//' -e "s/$/.$(date +%F-%H_%M_%S)/")
        TARGET="$BACKUPDIR/$TARGET"
        debug "Backuping $FILE to $TARGET"
        cp -a "$FILE" "$TARGET"
        # shellcheck disable=2034
        FNRET=0
    fi
}

#
# Logging functions
#

case $LOGLEVEL in
silent)
    MACHINE_LOG_LEVEL=0
    ;;
error)
    MACHINE_LOG_LEVEL=1
    ;;
warning)
    MACHINE_LOG_LEVEL=2
    ;;
ok)
    MACHINE_LOG_LEVEL=3
    ;;
info)
    MACHINE_LOG_LEVEL=4
    ;;
debug)
    MACHINE_LOG_LEVEL=5
    ;;
*)
    MACHINE_LOG_LEVEL=4 ## Default loglevel value to info
    ;;
esac

_logger() {
    COLOR=$1
    shift
    test -z "$SCRIPT_NAME" && SCRIPT_NAME=$(basename "$0")
    builtin echo "$*" | /usr/bin/logger -t "CIS_Hardening[$$] $SCRIPT_NAME" -p "user.info"
    SCRIPT_NAME_FIXEDLEN=$(printf "%-25.25s" "$SCRIPT_NAME")
    cecho "$COLOR" "$SCRIPT_NAME_FIXEDLEN $*"
}

becho() {
    toprint=$(echo "$*" | /usr/bin/tr '\n' ' ')
    builtin echo "$toprint" | /usr/bin/logger -t "CIS_Hardening[$$]" -p "user.info"
    builtin echo "$toprint"
}

cecho() {
    COLOR=$1
    shift
    builtin echo -e "${COLOR}$*${NC}"
}

crit() {
    if [ "${BATCH_MODE:-0}" -eq 1 ]; then
        BATCH_OUTPUT="$BATCH_OUTPUT KO{$*}"
    else
        if [ "$MACHINE_LOG_LEVEL" -ge 1 ]; then _logger "$BRED" "[ KO ] $*"; fi
    fi
    # This variable incrementation is used to measure failure or success in tests
    CRITICAL_ERRORS_NUMBER=$((CRITICAL_ERRORS_NUMBER + 1))
}

warn() {
    if [ "${BATCH_MODE:-0}" -eq 1 ]; then
        BATCH_OUTPUT="$BATCH_OUTPUT WARN{$*}"
    else
        if [ "$MACHINE_LOG_LEVEL" -ge 2 ]; then _logger "$BYELLOW" "[WARN] $*"; fi
    fi
}

ok() {
    if [ "${BATCH_MODE:-0}" -eq 1 ]; then
        BATCH_OUTPUT="$BATCH_OUTPUT OK{$*}"
    else
        if [ "$MACHINE_LOG_LEVEL" -ge 3 ]; then _logger "$BGREEN" "[ OK ] $*"; fi
    fi
}

info() {
    if [ "$MACHINE_LOG_LEVEL" -ge 4 ]; then _logger '' "[INFO] $*"; fi
}

debug() {
    if [ "$MACHINE_LOG_LEVEL" -ge 5 ]; then _logger "$GRAY" "[DBG ] $*"; fi
}

exception() {
    # Trap exit code is the same as the trapped one unless we call an explicit exit
    TRAP_CODE=$?
    if [ "$ACTIONS_DONE" -ne 1 ]; then
        if [ "$BATCH_MODE" -eq 1 ]; then
            BATCH_OUTPUT="KO $SCRIPT_NAME $BATCH_OUTPUT KO{Unexpected exit code: $TRAP_CODE}"
            becho "$BATCH_OUTPUT"
        else
            crit "Check failed with unexpected exit code: $TRAP_CODE"
        fi
        exit 1 # Means critical status
    fi
}

#
# sudo wrapper
# issue crit state if not allowed to perform sudo
# for the specified command
#
sudo_wrapper() {
    if sudo -l "$@" >/dev/null 2>&1; then
        sudo -n "$@"
    else
        crit "Not allowed to \"sudo -n $*\" "
    fi
}

#
# Math functions
#

div() {
    local _d=${3:-2}
    local _n=0000000000
    _n=${_n:0:$_d}
    if (($1 == 0)); then
        echo "0"
        return
    fi
    if (($2 == 0)); then
        echo "N.A"
        return
    fi
    local _r=$(($1$_n / $2))
    _r=${_r:0:-$_d}.${_r: -$_d}
    echo $_r
}
