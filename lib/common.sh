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
        TARGET=$(echo $FILE | sed -s 's/\//./g' | sed -s 's/^.//' | sed -s "s/$/.$(date +%F-%T)/" )
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
    /usr/bin/logger -t "[CIS_Hardening] $SCRIPT_NAME" -p "user.info" "$*"
    test -t 1 && cecho $COLOR "$SCRIPT_NAME $*"
}

cecho () {
    COLOR=$1
    shift
    echo -e "${COLOR}$*${NC}"
}

crit () {
    [ $MACHINE_LOG_LEVEL -ge 1 ] && _logger $BRED "[ KO ] $*"
}

warn () {
    [ $MACHINE_LOG_LEVEL -ge 2 ] && _logger $BYELLOW "[WARN] $*"
}

ok () {
    [ $MACHINE_LOG_LEVEL -ge 3 ] && _logger $BGREEN "[ OK ] $*"
}

info () {
    [ $MACHINE_LOG_LEVEL -ge 4 ] && _logger $BWHITE "[INFO] $*"
}

debug () {
    [ $MACHINE_LOG_LEVEL -ge 5 ] && _logger $GRAY "[DBG ] $*"
}
