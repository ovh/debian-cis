#!/bin/bash

#
# CIS Debian 7 Hardening
# Authors : Thibault Dewailly, OVH <thibault.dewailly@corp.ovh.com>
#

#
# Main script : Execute hardening considering configuration
#

LONG_SCRIPT_NAME=$(basename $0)
SCRIPT_NAME=${LONG_SCRIPT_NAME%.sh}
DISABLED_CHECKS=0
PASSED_CHECKS=0
FAILED_CHECKS=0
TOTAL_CHECKS=0
TOTAL_TREATED_CHECKS=0
AUDIT=0
APPLY=0

usage() {
    cat << EOF
$LONG_SCRIPT_NAME ( --apply | -- audit ) < -h | --help >
    --apply   : Apply hardening if told in configuration
    --audit   : If script not disabled, audit configuration only
    -h|--help : This help
EOF
    exit 0
}

if [ $# = 0 ]; then
    usage
fi

# Arguments parsing
while [[ $# > 0 ]]; do
    ARG="$1"
    case $ARG in
        --audit)
            AUDIT=1
        ;;
        --apply)
            APPLY=1
        ;;
        -h|--help)
            usage
        ;;
        *)
            usage
        ;;
    esac
    shift
done

# Source Root Dir Parameter
if [ ! -r /etc/default/cis-hardening ]; then
    echo "There is no /etc/default/cis-hardening file, cannot source CIS_ROOT_DIR variable, aborting"
    exit 128
else
    . /etc/default/cis-hardening
    if [ -z $CIS_ROOT_DIR ]; then
        echo "No CIS_ROOT_DIR variable, aborting"
    fi
fi 

[ -r $CIS_ROOT_DIR/lib/constants.sh  ] && . $CIS_ROOT_DIR/lib/constants.sh
[ -r $CIS_ROOT_DIR/etc/hardening.cfg ] && . $CIS_ROOT_DIR/etc/hardening.cfg
[ -r $CIS_ROOT_DIR/lib/common.sh     ] && . $CIS_ROOT_DIR/lib/common.sh
[ -r $CIS_ROOT_DIR/lib/utils.sh      ] && . $CIS_ROOT_DIR/lib/utils.sh

# Parse every scripts and execute them in the required mode
for SCRIPT in $(ls $CIS_ROOT_DIR/bin/hardening/*.sh | sort -V); do 
    info "Treating $SCRIPT"
    
    if [ $AUDIT = 1 ]; then
        debug "$CIS_ROOT_DIR/bin/hardening/$SCRIPT --audit"
        $SCRIPT --audit
    elif [ $APPLY = 1 ]; then
        debug "$CIS_ROOT_DIR/bin/hardening/$SCRIPT"
        $SCRIPT
    fi

    SCRIPT_EXITCODE=$?

    debug "Script $SCRIPT finished with exit code $SCRIPT_EXITCODE"
    case $SCRIPT_EXITCODE in
        0)
            debug "$SCRIPT passed"
            PASSED_CHECKS=$((PASSED_CHECKS+1))
        ;;    
        1)
            debug "$SCRIPT failed"
            FAILED_CHECKS=$((FAILED_CHECKS+1))
        ;;
        2)
            debug "$SCRIPT is disabled"
            DISABLED_CHECKS=$((DISABLED_CHECKS+1))
        ;;
    esac

    TOTAL_CHECKS=$((TOTAL_CHECKS+1))
 
done

TOTAL_TREATED_CHECKS=$((TOTAL_CHECKS-DISABLED_CHECKS))

printf "%40s\n" "################### SUMMARY ###################"
printf "%30s %s\n"        "Total Available Checks :" "$TOTAL_CHECKS"
printf "%30s %s\n"        "Total Runned Checks :" "$TOTAL_TREATED_CHECKS"
printf "%30s [ %7s ]\n"   "Total Passed Checks :" "$PASSED_CHECKS/$TOTAL_TREATED_CHECKS"
printf "%30s [ %7s ]\n"   "Total Failed Checks :" "$FAILED_CHECKS/$TOTAL_TREATED_CHECKS"
printf "%30s %.2f %%\n"   "Enabled Checks Percentage :" "$( echo "($TOTAL_TREATED_CHECKS/$TOTAL_CHECKS) * 100" | bc -l)"
if [ $TOTAL_TREATED_CHECKS != 0 ]; then
    printf "%30s %.2f %%\n"   "Conformity Percentage :" "$( echo "($PASSED_CHECKS/$TOTAL_TREATED_CHECKS) * 100" | bc -l)"
else
    printf "%30s %s %%\n"   "Conformity Percentage :" "N.A" # No check runned, avoid division by 0 
fi
