#!/bin/bash

#
# CIS Debian 7 Hardening
#

#
# 8.1.3 Enable Auditing for Processes That Start Prior to auditd (Scored)
#

set -e # One error, it's over
set -u # One variable unset, it's over

FILE='/etc/default/grub'
OPTIONS='GRUB_CMDLINE_LINUX="audit=1"'

# This function will be called if the script status is on enabled / audit mode
audit () {
    does_file_exist $FILE
    if [ $FNRET != 0 ]; then
        crit "$FILE does not exist"
    else
        ok "$FILE exist, checking configuration"
        for GRUB_OPTION in $OPTIONS; do
        GRUB_PARAM=$(echo $GRUB_OPTION | cut -d= -f 1)
        GRUB_VALUE=$(echo $GRUB_OPTION | cut -d= -f 2,3)
        PATTERN="^$GRUB_PARAM=$GRUB_VALUE"
        debug "$GRUB_PARAM must have value $GRUB_VALUE"
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
    for GRUB_OPTION in $OPTIONS; do
        GRUB_PARAM=$(echo $GRUB_OPTION | cut -d= -f 1)
        GRUB_VALUE=$(echo $GRUB_OPTION | cut -d= -f 2,3)
        debug "$GRUB_PARAM must have value $GRUB_VALUE"
        PATTERN="^$GRUB_PARAM=$GRUB_VALUE"
        does_pattern_exists_in_file $FILE "$PATTERN"
        if [ $FNRET != 0 ]; then
            warn "$PATTERN not present in $FILE, adding it"
            does_pattern_exists_in_file $FILE "^$GRUB_PARAM"
            if [ $FNRET != 0 ]; then
                info "Parameter $GRUB_PARAM seems absent from $FILE, adding at the end" 
                add_end_of_file $FILE "$GRUB_PARAM = $GRUB_VALUE"
            else
                info "Parameter $GRUB_PARAM is present but with the wrong value, correcting"
                replace_in_file $FILE "^$GRUB_PARAM=.*" "$GRUB_PARAM=$GRUB_VALUE"
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
if [ ! -r /etc/default/cis-hardening ]; then
    echo "There is no /etc/default/cis-hardening file, cannot source CIS_ROOT_DIR variable, aborting"
    exit 128
else
    . /etc/default/cis-hardening
    if [ -z $CIS_ROOT_DIR ]; then
        echo "No CIS_ROOT_DIR variable, aborting"
        exit 128
    fi
fi 

# Main function, will call the proper functions given the configuration (audit, enabled, disabled)
[ -r $CIS_ROOT_DIR/lib/main.sh ] && . $CIS_ROOT_DIR/lib/main.sh
