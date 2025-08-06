# shellcheck shell=bash
# run-shellcheck

SCRIPT_FULL_PATH=$(realpath -s "$0")
LONG_SCRIPT_NAME=$(basename "$0")
SCRIPT_NAME=${LONG_SCRIPT_NAME%.sh}
# Variable initialization, to avoid crash
CRITICAL_ERRORS_NUMBER=0 # This will be used to see if a script failed, or passed
BATCH_MODE=0
BATCH_OUTPUT=""
status=""
forcedstatus=""
SUDO_CMD=""
SAVED_LOGLEVEL=""
ACTIONS_DONE=0

if [ -n "${LOGLEVEL:-}" ]; then
    SAVED_LOGLEVEL=$LOGLEVEL
fi
# shellcheck source=../etc/hardening.cfg
[ -r "${CIS_CONF_DIR}"/hardening.cfg ] && . "${CIS_CONF_DIR}"/hardening.cfg
if [ -n "$SAVED_LOGLEVEL" ]; then
    LOGLEVEL=$SAVED_LOGLEVEL
fi
# shellcheck source=../lib/common.sh
[ -r "${CIS_LIB_DIR}"/common.sh ] && . "${CIS_LIB_DIR}"/common.sh
# shellcheck source=../lib/utils.sh
[ -r "${CIS_LIB_DIR}"/utils.sh ] && . "${CIS_LIB_DIR}"/utils.sh
# shellcheck source=constants.sh
[ -r "${CIS_LIB_DIR}"/constants.sh ] && . "${CIS_LIB_DIR}"/constants.sh

# Environment Sanitizing
export PATH='/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin'

# Arguments parsing
while [[ $# -gt 0 ]]; do
    ARG="$1"
    case $ARG in
    --audit-all)
        debug "Audit all specified, setting status to audit regardless of configuration"
        forcedstatus=auditall
        ;;
    --audit)
        if [ "$status" != 'disabled' ] && [ "$status" != 'false' ]; then
            debug "Audit argument detected, setting status to audit"
            forcedstatus=audit
        else
            info "Audit argument passed but script is disabled"
        fi
        ;;
    --create-config-files-only)
        debug "Create config files"
        forcedstatus=createconfig
        ;;
    --sudo)
        SUDO_CMD="sudo_wrapper"
        ;;
    --batch)
        debug "Auditing in batch mode, will limit output by setting LOGLEVEL to 'ok'."
        BATCH_MODE=1
        LOGLEVEL=ok
        # shellcheck source=../lib/common.sh
        [ -r "${CIS_LIB_DIR}"/common.sh ] && . "${CIS_LIB_DIR}"/common.sh
        ;;
    *)
        debug "Unknown option passed"
        ;;
    esac
    shift
done

info "Working on $SCRIPT_NAME"
info "[DESCRIPTION] $DESCRIPTION"

# check if the script is a link
# if a file, script is executed from "bin/hardening", create a cfg file (if not already exists)
# if a link, script is executed from "version"/X", create a link, or update it if already exits
if [ -L "${SCRIPT_FULL_PATH}" ]; then
    # script is a link
    script_real_path=$(readlink -f "${SCRIPT_FULL_PATH}")
    script_real_name=$(basename "$script_real_path")
    cfg_file=$(basename -s .sh "$script_real_path").cfg
    cfg_link="$SCRIPT_NAME".cfg
else
    # script is a file
    script_real_name=$LONG_SCRIPT_NAME
    cfg_file="$SCRIPT_NAME".cfg
    cfg_link=""
fi

# Source specific configuration file
if ! [ -r "${CIS_CONF_DIR}"/conf.d/"$cfg_file" ]; then
    # If it doesn't exist, create it with default values
    echo "# Configuration for $script_real_name, created from default values on $(date)" >"${CIS_CONF_DIR}"/conf.d/"$cfg_file"
    # If create_config is a defined function, execute it.
    # Otherwise, just disable the test by default.
    if type -t create_config | grep -qw function; then
        create_config >>"${CIS_CONF_DIR}"/conf.d/"$cfg_file"
    else
        echo "status=audit" >>"${CIS_CONF_DIR}"/conf.d/"$cfg_file"
    fi
fi

if [ -n "$cfg_link" ]; then
    if [ -f "${CIS_CONF_DIR}"/conf.d/"$cfg_link" ]; then
        rm -f "${CIS_CONF_DIR}"/conf.d/"$cfg_link"
    fi
    ln -fs "${CIS_CONF_DIR}"/conf.d/"$cfg_file" "${CIS_CONF_DIR}"/conf.d/"$cfg_link"
fi

if [ "$forcedstatus" = "createconfig" ]; then
    debug "${CIS_CONF_DIR}/conf.d/$SCRIPT_NAME.cfg has been created"
    exit 0
fi
# shellcheck source=/dev/null
[ -r "${CIS_CONF_DIR}"/conf.d/"$SCRIPT_NAME".cfg ] && . "${CIS_CONF_DIR}"/conf.d/"$SCRIPT_NAME".cfg

# Now check configured value for status, and potential cmdline parameter
if [ "$forcedstatus" = "auditall" ]; then
    # We want to audit even disabled script, so override config value in any case
    status=audit
elif [ "$forcedstatus" = "audit" ]; then
    # We want to audit only enabled scripts
    if [ "$status" != 'disabled' ] && [ "$status" != 'false' ]; then
        debug "Audit argument detected, setting status to audit"
        status=audit
    else
        info "Audit argument passed but script is disabled"
    fi
fi

if [ -z "$status" ]; then
    crit "Could not find status variable for $SCRIPT_NAME, considered as disabled"

    exit 2
fi

# We want to trap unexpected failures in check scripts
trap exception EXIT

case $status in
enabled | true)
    info "Checking Configuration"
    check_config
    info "Performing audit"
    audit # Perform audit
    info "Applying Hardening"
    apply # Perform hardening
    ;;
audit)
    info "Checking Configuration"
    check_config
    info "Performing audit"
    audit # Perform audit
    ;;
disabled | false)
    info "$SCRIPT_NAME is disabled, ignoring"
    ACTIONS_DONE=1
    exit 2 # Means unknown status
    ;;
*)
    warn "Wrong value for status : $status. Must be [ enabled | true | audit | disabled | false ]"
    ;;
esac

ACTIONS_DONE=1

if [ "$CRITICAL_ERRORS_NUMBER" -eq 0 ]; then
    if [ "$BATCH_MODE" -eq 1 ]; then
        BATCH_OUTPUT="OK $SCRIPT_NAME $BATCH_OUTPUT"
        becho "$BATCH_OUTPUT"
    else
        ok "Check Passed"
    fi
    exit 0 # Means ok status
else
    if [ "$BATCH_MODE" -eq 1 ]; then
        BATCH_OUTPUT="KO $SCRIPT_NAME $BATCH_OUTPUT"
        becho "$BATCH_OUTPUT"
    else
        crit "Check Failed"
    fi
    exit 1 # Means critical status
fi
