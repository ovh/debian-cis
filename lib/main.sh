LONG_SCRIPT_NAME=$(basename $0)
SCRIPT_NAME=${LONG_SCRIPT_NAME%.sh}
# Variable initialization, to avoid crash
CRITICAL_ERRORS_NUMBER=0 # This will be used to see if a script failed, or passed
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
    exit 2
fi

# Arguments parsing
while [[ $# > 0 ]]; do
    ARG="$1"
    case $ARG in
        --audit-all)
            debug "Audit all specified, setting status to audit regardless of configuration"
            status=audit
        ;;
        --audit)
        if [ $status != 'disabled' -a $status != 'false' ]; then
            debug "Audit argument detected, setting status to audit"
            status=audit
        else
            info "Audit argument passed but script is disabled"
        fi
        ;;
        *)
            debug "Unknown option passed"
        ;;
    esac
    shift
done

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
        exit 2 # Means unknown status
        ;;
    *)
        warn "Wrong value for status : $status. Must be [ enabled | true | audit | disabled | false ]"
        ;;
esac

if [ $CRITICAL_ERRORS_NUMBER = 0 ]; then
    ok "Check Passed"
    exit 0 # Means ok status
else
    crit "Check Failed"
    exit 1 # Means critical status
fi
