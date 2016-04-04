LONG_SCRIPT_NAME=$(basename $0)
SCRIPT_NAME=${LONG_SCRIPT_NAME%.sh}
# Variable initialization, to avoid crash
status=""

[ -r $CIS_ROOT_DIR/lib/constants.sh  ] && . $CIS_ROOT_DIR/lib/constants.sh
[ -r $CIS_ROOT_DIR/etc/hardening.cfg ] && . $CIS_ROOT_DIR/etc/hardening.cfg
[ -r $CIS_ROOT_DIR/lib/common.sh     ] && . $CIS_ROOT_DIR/lib/common.sh
[ -r $CIS_ROOT_DIR/lib/utils.sh      ] && . $CIS_ROOT_DIR/lib/utils.sh

# Source specific configuration file
[ -r $CIS_ROOT_DIR/etc/conf.d/$SCRIPT_NAME.cfg ] && . $CIS_ROOT_DIR/etc/conf.d/$SCRIPT_NAME.cfg

# Environment Sanitizing
export PATH='/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin'

info "Working on $SCRIPT_NAME"

if [ -z $status ]; then
    crit "Could not find status variable for $SCRIPT_NAME, considered as disabled"
    exit 0
fi

case $status in
    enabled | true )
        info "Checking Configuration"
        check_config
        info "Performing audit"
        audit # Perform audit
        info "Applying Hardening"
        apply # Perform hardening
        ;;
    audit )
        info "Checking Configuration"
        check_config
        info "Performing audit"
        audit # Perform audit
        ;;
    disabled | false )
        info "$SCRIPT_NAME is disabled, ignoring"
        ;;
    *)
        warn "Wrong value for status : $status. Must be [ enabled | true | audit | disabled | false ]"
        ;;
esac
