#!/bin/bash

# run-shellcheck
#
# CIS Debian Hardening
#

#
# Ensure file deletion events by users are collected
#

set -e # One error, it's over
set -u # One variable unset, it's over

# shellcheck disable=2034
HARDENING_LEVEL=4
# shellcheck disable=2034
DESCRIPTION="Ensure file deletion events are audited"

AUDIT_RULES_FILE="/etc/audit/rules.d/50-delete.rules"

# This function will be called if the script status is on enabled / audit mode
audit() {
    if [ ! -f "$AUDIT_RULES_FILE" ]; then
        crit "Audit rules file $AUDIT_RULES_FILE does not exist"
        FNRET=1
        return
    fi

    UID_MIN=$(awk '/^\s*UID_MIN/{print $2}' /etc/login.defs)
    if [ -z "$UID_MIN" ]; then
        crit "Unable to determine UID_MIN from /etc/login.defs"
        FNRET=1
        return
    fi

    # Check for required rules
    RULES_OK=0
    if grep -q "^\-a always,exit \-F arch=b64 \-S unlink,unlinkat,rename,renameat \-F auid>=${UID_MIN} \-F auid!=unset \-k delete" "$AUDIT_RULES_FILE" &&
        grep -q "^\-a always,exit \-F arch=b32 \-S unlink,unlinkat,rename,renameat \-F auid>=${UID_MIN} \-F auid!=unset \-k delete" "$AUDIT_RULES_FILE"; then
        RULES_OK=1
    fi

    if [ "$RULES_OK" -eq 1 ]; then
        ok "File deletion events are correctly configured in $AUDIT_RULES_FILE"
        FNRET=0
    else
        crit "File deletion events rules are not correctly configured in $AUDIT_RULES_FILE"
        FNRET=2
    fi
}

# This function will be called if the script status is on enabled mode
apply() {
    if [ "$FNRET" -eq 0 ]; then
        ok "File deletion events are already correctly configured"
    elif [ "$FNRET" -eq 1 ]; then
        warn "Creating audit rules file $AUDIT_RULES_FILE"
        UID_MIN=$(awk '/^\s*UID_MIN/{print $2}' /etc/login.defs)
        if [ -z "$UID_MIN" ]; then
            crit "Unable to determine UID_MIN from /etc/login.defs"
            return
        fi

        cat >"$AUDIT_RULES_FILE" <<EOF
# Ensure file deletion events by users are collected
-a always,exit -F arch=b64 -S unlink,unlinkat,rename,renameat -F auid>=${UID_MIN} -F auid!=unset -k delete
-a always,exit -F arch=b32 -S unlink,unlinkat,rename,renameat -F auid>=${UID_MIN} -F auid!=unset -k delete
EOF

        augenrules --load
        ok "File deletion audit rules created and loaded"
    elif [ "$FNRET" -eq 2 ]; then
        warn "Updating audit rules in $AUDIT_RULES_FILE"
        UID_MIN=$(awk '/^\s*UID_MIN/{print $2}' /etc/login.defs)

        # Remove any existing delete rules
        sed -i '/\-k delete/d' "$AUDIT_RULES_FILE"

        # Add correct rules
        cat >>"$AUDIT_RULES_FILE" <<EOF
# Ensure file deletion events by users are collected
-a always,exit -F arch=b64 -S unlink,unlinkat,rename,renameat -F auid>=${UID_MIN} -F auid!=unset -k delete
-a always,exit -F arch=b32 -S unlink,unlinkat,rename,renameat -F auid>=${UID_MIN} -F auid!=unset -k delete
EOF

        augenrules --load
        ok "File deletion audit rules updated and loaded"
    fi
}

# This function will check config parameters required
check_config() {
    :
}

# Source Root Dir Parameter
if [ -r /etc/default/cis-hardening ]; then
    # shellcheck source=../../debian/default
    . /etc/default/cis-hardening
fi
if [ -z "$CIS_LIB_DIR" ]; then
    echo "There is no /etc/default/cis-hardening file nor cis-hardening directory in current environment."
    echo "Cannot source CIS_LIB_DIR variable, aborting."
    exit 128
fi

# Main function, will call the proper functions given the configuration (audit, enabled, disabled)
if [ -r "${CIS_LIB_DIR}"/main.sh ]; then
    # shellcheck source=../../lib/main.sh
    . "${CIS_LIB_DIR}"/main.sh
else
    echo "Cannot find main.sh, have you correctly defined your root directory? Current value is $CIS_LIB_DIR in /etc/default/cis-hardening"
    exit 128
fi
