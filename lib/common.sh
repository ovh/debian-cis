# CIS Debian 7 Hardening common functions

#
# File Backup functions
#
backup_file() {
    FILE=$1
    if [ ! -f $FILE ]; then
        crit "Cannot backup $FILE, it's not a file"
        FNRET=1
    else
        TARGET=$(echo $FILE | sed -s -e 's/\//./g' -e 's/^.//' -e "s/$/.$(date +%F-%H_%M_%S)/" )
        TARGET="$BACKUPDIR/$TARGET"
        debug "Backuping $FILE to $TARGET"
        cp -a $FILE $TARGET
        FNRET=0
    fi
}


#
# Logging functions
#

case $LOGLEVEL in
    error )
        MACHINE_LOG_LEVEL=1
        ;;
    warning )
        MACHINE_LOG_LEVEL=2
        ;;
    ok )
        MACHINE_LOG_LEVEL=3
        ;;
    info )
        MACHINE_LOG_LEVEL=4
        ;;
    debug )
        MACHINE_LOG_LEVEL=5
        ;;
    *)
        MACHINE_LOG_LEVEL=4 ## Default loglevel value to info
esac

_logger() {
    COLOR=$1
    shift
    test -z "$SCRIPT_NAME" && SCRIPT_NAME=$(basename $0)
    builtin echo "$*" | /usr/bin/logger -t "[CIS_Hardening] $SCRIPT_NAME" -p "user.info"
    cecho $COLOR "$SCRIPT_NAME $*"
}

cecho () {
    COLOR=$1
    shift
    builtin echo -e "${COLOR}$*${NC}"
}

crit () {
    if [ $MACHINE_LOG_LEVEL -ge 1 ]; then _logger $BRED "[ KO ] $*"; fi
    # This variable incrementation is used to measure failure or success in tests
    CRITICAL_ERRORS_NUMBER=$((CRITICAL_ERRORS_NUMBER+1))
}

warn () {
    if [ $MACHINE_LOG_LEVEL -ge 2 ]; then _logger $BYELLOW "[WARN] $*"; fi
}

ok () {
    if [ $MACHINE_LOG_LEVEL -ge 3 ]; then _logger $BGREEN "[ OK ] $*"; fi
}

info () {
    if [ $MACHINE_LOG_LEVEL -ge 4 ]; then _logger $BWHITE "[INFO] $*"; fi
}

debug () {
    if [ $MACHINE_LOG_LEVEL -ge 5 ]; then _logger $GRAY "[DBG ] $*"; fi
}
