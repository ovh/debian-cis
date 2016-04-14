#!/bin/bash

#
# CIS Debian 7 Hardening
# Authors : Thibault Dewailly, OVH <thibault.dewailly@corp.ovh.com>
#

#
# 8.1.1.3 Keep All Auditing Information (Scored)
#

set -e # One error, it's over
set -u # One variable unset, it's over

FILE='/etc/audit/auditd.conf'
OPTIONS='max_log_file_action=keep_logs'

# This function will be called if the script status is on enabled / audit mode
audit () {
    does_file_exist $FILE
    if [ $FNRET != 0 ]; then
        crit "$FILE does not exist"
    else
        ok "$FILE exist, checking configuration"
        for AUDIT_OPTION in $OPTIONS; do
        AUDIT_PARAM=$(echo $AUDIT_OPTION | cut -d= -f 1)
        AUDIT_VALUE=$(echo $AUDIT_OPTION | cut -d= -f 2)
        PATTERN="^$AUDIT_PARAM[[:space:]]*=[[:space:]]*$AUDIT_VALUE"
        debug "$AUDIT_PARAM must have value $AUDIT_VALUE"
        does_pattern_exists_in_file $FILE "$PATTERN"
        if [ $FNRET != 0 ]; then
            crit "$PATTERN not present in $FILE"
        else
            ok "$PATTERN present in $FILE"
        fi
        done
    fi
}

# This function will be called if the script status is on enabled mode
apply () {
    does_file_exist $FILE
    if [ $FNRET != 0 ]; then
        warn "$FILE does not exist, creating it"
        touch $FILE
    else
        ok "$FILE exist"
    fi
    for AUDIT_OPTION in $OPTIONS; do
        AUDIT_PARAM=$(echo $AUDIT_OPTION | cut -d= -f 1)
        AUDIT_VALUE=$(echo $AUDIT_OPTION | cut -d= -f 2)
        debug "$AUDIT_PARAM must have value $AUDIT_VALUE"
        PATTERN="^$AUDIT_PARAM[[:space:]]*=[[:space:]]*$AUDIT_VALUE"
        does_pattern_exists_in_file $FILE "$PATTERN"
        if [ $FNRET != 0 ]; then
            warn "$PATTERN not present in $FILE, adding it"
            does_pattern_exists_in_file $FILE "^$AUDIT_PARAM"
            if [ $FNRET != 0 ]; then
                info "Parameter $AUDIT_PARAM seems absent from $FILE, adding at the end" 
                add_end_of_file $FILE "$AUDIT_PARAM = $AUDIT_VALUE"
            else
                info "Parameter $AUDIT_PARAM is present but with the wrong value, correcting"
                replace_in_file $FILE "^$AUDIT_PARAM[[:space:]]*=.*" "$AUDIT_PARAM = $AUDIT_VALUE"
            fi
        else
            ok "$PATTERN present in $FILE"
        fi
    done
}

# This function will check config parameters required
check_config() {
    :
}

# Source Root Dir Parameter
if [ ! -r /etc/default/cis-hardenning ]; then
    echo "There is no /etc/default/cis-hardenning file, cannot source CIS_ROOT_DIR variable, aborting"
    exit 128
else
    . /etc/default/cis-hardenning
    if [ -z $CIS_ROOT_DIR ]; then
        echo "No CIS_ROOT_DIR variable, aborting"
    fi
fi 

# Main function, will call the proper functions given the configuration (audit, enabled, disabled)
[ -r $CIS_ROOT_DIR/lib/main.sh ] && . $CIS_ROOT_DIR/lib/main.sh
