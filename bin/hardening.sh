#!/bin/bash

# run-shellcheck
#
# CIS Debian Hardening
# Authors : Thibault Dewailly, OVH <thibault.dewailly@corp.ovh.com>
#

#
# Main script : Execute hardening considering configuration
#

LONG_SCRIPT_NAME=$(basename "$0")
SCRIPT_NAME=${LONG_SCRIPT_NAME%.sh}
DISABLED_CHECKS=0
PASSED_CHECKS=0
FAILED_CHECKS=0
TOTAL_CHECKS=0
TOTAL_TREATED_CHECKS=0
AUDIT=0
APPLY=0
AUDIT_ALL=0
AUDIT_ALL_ENABLE_PASSED=0
CREATE_CONFIG=0
ALLOW_SERVICE_LIST=0
SET_HARDENING_LEVEL=0
SUDO_MODE=''
BATCH_MODE=''
SUMMARY_JSON=''
ASK_LOGLEVEL=''
ALLOW_UNSUPPORTED_DISTRIBUTION=0

usage() {
    cat <<EOF
$LONG_SCRIPT_NAME <RUN_MODE> [OPTIONS], where RUN_MODE is one of:

    --help -h
        Show this help

    --apply
        Apply hardening for enabled scripts.
        Beware that NO confirmation is asked whatsoever, which is why you're warmly
        advised to use --audit before, which can be regarded as a dry-run mode.

    --audit
        Audit configuration for enabled scripts.
        No modification will be made on the system, we'll only report on your system
        compliance for each script.

    --audit-all
        Same as --audit, but for *all* scripts, even disabled ones.
        This is a good way to peek at your compliance level if all scripts were enabled,
        and might be a good starting point.

    --audit-all-enable-passed
        Same as --audit-all, but in addition, will *modify* the individual scripts
        configurations to enable those which passed for your system.
        This is an easy way to enable scripts for which you're already compliant.
        However, please always review each activated script afterwards, this option
        should only be regarded as a way to kickstart a configuration from scratch.
        Don't run this if you have already customized the scripts enable/disable
        configurations, obviously.

    --set-hardening-level <level>
        Modifies the configuration to enable/disable tests given an hardening level,
        between 1 to 5. Don't run this if you have already customized the scripts
        enable/disable configurations.
        1: very basic policy, failure to pass tests at this level indicates severe
            misconfiguration of the machine that can have a huge security impact
        2: basic policy, some good practice rules that, once applied, shouldn't
            break anything on most systems
        3: best practices policy, passing all tests might need some configuration
            modifications (such as specific partitioning, etc.)
        4: high security policy, passing all tests might be time-consuming and
            require high adaptation of your workflow
        5: placebo, policy rules that might be very difficult to apply and maintain,
            with questionable security benefits

    --allow-service <service>
        Use with --set-hardening-level.
        Modifies the policy to allow a certain kind of services on the machine, such
        as http, mail, etc. Can be specified multiple times to allow multiple services.
        Use --allow-service-list to get a list of supported services.

    --create-config-files-only
        Create the config files in etc/conf.d
        Must be run as root, before running the audit with user secaudit

OPTIONS:

    --only <test_number>
        Modifies the RUN_MODE to only work on the test_number script.
        Can be specified multiple times to work only on several scripts.
        The test number is the numbered prefix of the script,
        i.e. the test number of 1.2_script_name.sh is 1.2.

    --sudo
        This option lets you audit your system as a normal user, but allows sudo
        escalation to gain read-only access to root files. Note that you need to
        provide a sudoers file with NOPASSWD option in /etc/sudoers.d/ because
        the '-n' option instructs sudo not to prompt for a password.
        Finally note that '--sudo' mode only works for audit mode.

    --set-log-level <level>
        This option sets LOGLEVEL, you can choose : info, warning, error, ok, debug or silent.
        Default value is : info

    --summary-json
        While performing system audit, this option sets LOGLEVEL to silent and
        only output a json summary at the end

    --batch
        While performing system audit, this option sets LOGLEVEL to 'ok' and
        captures all output to print only one line once the check is done, formatted like :
        OK|KO OK|KO|WARN{subcheck results} [OK|KO|WARN{...}]

    --allow-unsupported-distribution
        Must be specified manually in the command line to allow the run on non compatible
        version or distribution. If you want to mute the warning change the LOGLEVEL
        in /etc/hardening.cfg

EOF
    exit 0
}

if [ $# = 0 ]; then
    usage
fi

declare -a TEST_LIST ALLOWED_SERVICES_LIST

# Arguments parsing
while [[ $# -gt 0 ]]; do
    ARG="$1"
    case $ARG in
    --audit)
        AUDIT=1
        ;;
    --audit-all)
        AUDIT_ALL=1
        ;;
    --audit-all-enable-passed)
        AUDIT_ALL_ENABLE_PASSED=1
        ;;
    --apply)
        APPLY=1
        ;;
    --allow-service-list)
        ALLOW_SERVICE_LIST=1
        ;;
    --create-config-files-only)
        CREATE_CONFIG=1
        ;;
    --allow-service)
        ALLOWED_SERVICES_LIST[${#ALLOWED_SERVICES_LIST[@]}]="$2"
        shift
        ;;
    --set-hardening-level)
        SET_HARDENING_LEVEL="$2"
        shift
        ;;
    --set-log-level)
        ASK_LOGLEVEL=$2
        shift
        ;;
    --only)
        TEST_LIST[${#TEST_LIST[@]}]="$2"
        shift
        ;;
    --sudo)
        SUDO_MODE='--sudo'
        ;;
    --summary-json)
        SUMMARY_JSON='--summary-json'
        ASK_LOGLEVEL=silent
        ;;
    --batch)
        BATCH_MODE='--batch'
        ASK_LOGLEVEL=ok
        ;;
    --allow-unsupported-distribution)
        ALLOW_UNSUPPORTED_DISTRIBUTION=1
        ;;
    -h | --help)
        usage
        ;;
    *)
        usage
        ;;
    esac
    shift
done

# if no RUN_MODE was passed, usage and quit
if [ "$AUDIT" -eq 0 ] && [ "$AUDIT_ALL" -eq 0 ] && [ "$AUDIT_ALL_ENABLE_PASSED" -eq 0 ] && [ "$APPLY" -eq 0 ] && [ "$CREATE_CONFIG" -eq 0 ]; then
    usage
fi

# Source Root Dir Parameter
if [ -r /etc/default/cis-hardening ]; then
    # shellcheck source=../debian/default
    . /etc/default/cis-hardening
fi
if [ -z "$CIS_ROOT_DIR" ]; then
    echo "There is no /etc/default/cis-hardening file nor cis-hardening directory in current environment."
    echo "Cannot source CIS_ROOT_DIR variable, aborting."
    exit 128
fi

# shellcheck source=../etc/hardening.cfg
[ -r "$CIS_ROOT_DIR"/etc/hardening.cfg ] && . "$CIS_ROOT_DIR"/etc/hardening.cfg
if [ "$ASK_LOGLEVEL" ]; then LOGLEVEL=$ASK_LOGLEVEL; fi
# shellcheck source=../lib/common.sh
[ -r "$CIS_ROOT_DIR"/lib/common.sh ] && . "$CIS_ROOT_DIR"/lib/common.sh
# shellcheck source=../lib/utils.sh
[ -r "$CIS_ROOT_DIR"/lib/utils.sh ] && . "$CIS_ROOT_DIR"/lib/utils.sh
# shellcheck source=../lib/constants.sh
[ -r "$CIS_ROOT_DIR"/lib/constants.sh ] && . "$CIS_ROOT_DIR"/lib/constants.sh

# If we're on a unsupported platform and there is no flag --allow-unsupported-distribution
# print warning, otherwise quit

if [ "$DISTRIBUTION" != "debian" ]; then
    echo "Your distribution has been identified as $DISTRIBUTION which is not debian"
    if [ "$ALLOW_UNSUPPORTED_DISTRIBUTION" -eq 0 ]; then
        echo "If you want to run it anyway, you can use the flag --allow-unsupported-distribution"
        echo "Exiting now"
        exit 100
    elif [ "$ALLOW_UNSUPPORTED_DISTRIBUTION" -eq 0 ] && [ "$MACHINE_LOG_LEVEL" -ge 2 ]; then
        echo "Be aware that the result given by this set of scripts can give you a false feedback of security on unsupported distributions !"
        echo "You can deactivate this message by setting the LOGLEVEL variable in /etc/hardening.cfg"
    fi
else
    if [ "$DEB_MAJ_VER" = "sid" ] || [ "$DEB_MAJ_VER" -gt "$HIGHEST_SUPPORTED_DEBIAN_VERSION" ]; then
        echo "Your debian version is too recent and is not supported yet because there is no official CIS PDF for this version yet."
        if [ "$ALLOW_UNSUPPORTED_DISTRIBUTION" -eq 0 ]; then
            echo "If you want to run it anyway, you can use the flag --allow-unsupported-distribution"
            echo "Exiting now"
            exit 100
        elif [ "$ALLOW_UNSUPPORTED_DISTRIBUTION" -eq 0 ] && [ "$MACHINE_LOG_LEVEL" -ge 2 ]; then
            echo "Be aware that the result given by this set of scripts can give you a false feedback of security on unsupported distributions !"
            echo "You can deactivate this message by setting the LOGLEVEL variable in /etc/hardening.cfg"
        fi
    elif [ "$DEB_MAJ_VER" -lt "$SMALLEST_SUPPORTED_DEBIAN_VERSION" ]; then
        echo "Your debian version is deprecated and is no more maintained. Please upgrade to a supported version."
        if [ "$ALLOW_UNSUPPORTED_DISTRIBUTION" -eq 0 ]; then
            echo "If you want to run it anyway, you can use the flag --allow-unsupported-distribution"
            echo "Exiting now"
            exit 100
        elif [ "$ALLOW_UNSUPPORTED_DISTRIBUTION" -eq 0 ] && [ "$MACHINE_LOG_LEVEL" -ge 2 ]; then
            echo "Be aware that the result given by this set of scripts can give you a false feedback of security on unsupported distributions, especially on deprecated ones !"
            echo "You can deactivate this message by setting the LOGLEVEL variable in /etc/hardening.cfg"
        fi
    fi
fi

# If --allow-service-list is specified, don't run anything, just list the supported services
if [ "$ALLOW_SERVICE_LIST" = 1 ]; then
    declare -a HARDENING_EXCEPTIONS_LIST
    for SCRIPT in $(find "$CIS_ROOT_DIR"/bin/hardening/ -name "*.sh" | sort -V); do
        template=$(grep "^HARDENING_EXCEPTION=" "$SCRIPT" | cut -d= -f2)
        [ -n "$template" ] && HARDENING_EXCEPTIONS_LIST[${#HARDENING_EXCEPTIONS_LIST[@]}]="$template"
    done
    echo "Supported services are:" "$(echo "${HARDENING_EXCEPTIONS_LIST[@]}" | tr " " "\n" | sort -u | tr "\n" " ")"
    exit 0
fi

# If --set-hardening-level is specified, don't run anything, just apply config for each script
if [ -n "$SET_HARDENING_LEVEL" ] && [ "$SET_HARDENING_LEVEL" != 0 ]; then
    if ! grep -q "^[12345]$" <<<"$SET_HARDENING_LEVEL"; then
        echo "Bad --set-hardening-level specified ('$SET_HARDENING_LEVEL'), expected 1 to 5"
        exit 1
    fi

    for SCRIPT in $(find "$CIS_ROOT_DIR"/bin/hardening/ -name "*.sh" | sort -V); do
        SCRIPT_BASENAME=$(basename "$SCRIPT" .sh)
        script_level=$(grep "^HARDENING_LEVEL=" "$SCRIPT" | cut -d= -f2)
        if [ -z "$script_level" ]; then
            echo "The script $SCRIPT_BASENAME doesn't have a hardening level, configuration untouched for it"
            continue
        fi
        wantedstatus=disabled
        [ "$script_level" -le "$SET_HARDENING_LEVEL" ] && wantedstatus=enabled
        sed -i -re "s/^status=.+/status=$wantedstatus/" "$CIS_ROOT_DIR/etc/conf.d/$SCRIPT_BASENAME.cfg"
    done
    echo "Configuration modified to enable scripts for hardening level at or below $SET_HARDENING_LEVEL"
    exit 0
fi

if [ "$CREATE_CONFIG" = 1 ] && [ "$EUID" -ne 0 ]; then
    echo "For --create-config-files-only, please run as root"
    exit 1
fi

# Parse every scripts and execute them in the required mode
for SCRIPT in $(find "$CIS_ROOT_DIR"/bin/hardening/ -name "*.sh" | sort -V); do
    if [ "${#TEST_LIST[@]}" -gt 0 ]; then
        # --only X has been specified at least once, is this script in my list ?
        SCRIPT_PREFIX=$(grep -Eo '^[0-9.]+' <<<"$(basename "$SCRIPT")")
        # shellcheck disable=SC2001
        SCRIPT_PREFIX_RE=$(sed -e 's/\./\\./g' <<<"$SCRIPT_PREFIX")
        if ! grep -qwE "(^| )$SCRIPT_PREFIX_RE" <<<"${TEST_LIST[@]}"; then
            # not in the list
            continue
        fi
    fi

    info "Treating $SCRIPT"
    if [ "$CREATE_CONFIG" = 1 ]; then
        debug "$CIS_ROOT_DIR/bin/hardening/$SCRIPT --create-config-files-only"
        LOGLEVEL=$LOGLEVEL "$SCRIPT" --create-config-files-only "$BATCH_MODE"
    elif [ "$AUDIT" = 1 ]; then
        debug "$CIS_ROOT_DIR/bin/hardening/$SCRIPT --audit $SUDO_MODE $BATCH_MODE"
        LOGLEVEL=$LOGLEVEL "$SCRIPT" --audit "$SUDO_MODE" "$BATCH_MODE"
    elif [ "$AUDIT_ALL" = 1 ]; then
        debug "$CIS_ROOT_DIR/bin/hardening/$SCRIPT --audit-all $SUDO_MODE $BATCH_MODE"
        LOGLEVEL=$LOGLEVEL "$SCRIPT" --audit-all "$SUDO_MODE" "$BATCH_MODE"
    elif [ "$AUDIT_ALL_ENABLE_PASSED" = 1 ]; then
        debug "$CIS_ROOT_DIR/bin/hardening/$SCRIPT --audit-all $SUDO_MODE $BATCH_MODE"
        LOGLEVEL=$LOGLEVEL "$SCRIPT" --audit-all "$SUDO_MODE" "$BATCH_MODE"
    elif [ "$APPLY" = 1 ]; then
        debug "$CIS_ROOT_DIR/bin/hardening/$SCRIPT"
        LOGLEVEL=$LOGLEVEL "$SCRIPT"
    fi

    SCRIPT_EXITCODE=$?

    debug "Script $SCRIPT finished with exit code $SCRIPT_EXITCODE"
    case $SCRIPT_EXITCODE in
    0)
        debug "$SCRIPT passed"
        PASSED_CHECKS=$((PASSED_CHECKS + 1))
        if [ "$AUDIT_ALL_ENABLE_PASSED" = 1 ]; then
            SCRIPT_BASENAME=$(basename "$SCRIPT" .sh)
            sed -i -re 's/^status=.+/status=enabled/' "$CIS_ROOT_DIR/etc/conf.d/$SCRIPT_BASENAME.cfg"
            info "Status set to enabled in $CIS_ROOT_DIR/etc/conf.d/$SCRIPT_BASENAME.cfg"
        fi
        ;;
    1)
        debug "$SCRIPT failed"
        FAILED_CHECKS=$((FAILED_CHECKS + 1))
        ;;
    2)
        debug "$SCRIPT is disabled"
        DISABLED_CHECKS=$((DISABLED_CHECKS + 1))
        ;;
    esac

    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))

done

TOTAL_TREATED_CHECKS=$((TOTAL_CHECKS - DISABLED_CHECKS))

if [ "$BATCH_MODE" ]; then
    BATCH_SUMMARY="AUDIT_SUMMARY "
    BATCH_SUMMARY+="PASSED_CHECKS:${PASSED_CHECKS:-0} "
    BATCH_SUMMARY+="RUN_CHECKS:${TOTAL_TREATED_CHECKS:-0} "
    BATCH_SUMMARY+="TOTAL_CHECKS_AVAIL:${TOTAL_CHECKS:-0}"
    if [ "$TOTAL_TREATED_CHECKS" != 0 ]; then
        CONFORMITY_PERCENTAGE=$(div $((PASSED_CHECKS * 100)) $TOTAL_TREATED_CHECKS)
        BATCH_SUMMARY+=" CONFORMITY_PERCENTAGE:$(printf "%s" "$CONFORMITY_PERCENTAGE")"
    else
        BATCH_SUMMARY+=" CONFORMITY_PERCENTAGE:N.A" # No check runned, avoid division by 0
    fi
    becho "$BATCH_SUMMARY"
elif [ "$SUMMARY_JSON" ]; then
    if [ "$TOTAL_TREATED_CHECKS" != 0 ]; then
        CONFORMITY_PERCENTAGE=$(div $((PASSED_CHECKS * 100)) $TOTAL_TREATED_CHECKS)
    else
        CONFORMITY_PERCENTAGE=0 # No check runned, avoid division by 0
    fi
    printf '{'
    printf '"available_checks": %s, ' "$TOTAL_CHECKS"
    printf '"run_checks": %s, ' "$TOTAL_TREATED_CHECKS"
    printf '"passed_checks": %s, ' "$PASSED_CHECKS"
    printf '"conformity_percentage": %s' "$CONFORMITY_PERCENTAGE"
    printf '}\n'
else
    printf "%40s\n" "################### SUMMARY ###################"
    printf "%30s %s\n" "Total Available Checks :" "$TOTAL_CHECKS"
    printf "%30s %s\n" "Total Runned Checks :" "$TOTAL_TREATED_CHECKS"
    printf "%30s [ %7s ]\n" "Total Passed Checks :" "$PASSED_CHECKS/$TOTAL_TREATED_CHECKS"
    printf "%30s [ %7s ]\n" "Total Failed Checks :" "$FAILED_CHECKS/$TOTAL_TREATED_CHECKS"

    ENABLED_CHECKS_PERCENTAGE=$(div $((TOTAL_TREATED_CHECKS * 100)) $TOTAL_CHECKS)
    CONFORMITY_PERCENTAGE=$(div $((PASSED_CHECKS * 100)) $TOTAL_TREATED_CHECKS)
    printf "%30s %s %%\n" "Enabled Checks Percentage :" "$ENABLED_CHECKS_PERCENTAGE"
    if [ "$TOTAL_TREATED_CHECKS" != 0 ]; then
        printf "%30s %s %%\n" "Conformity Percentage :" "$CONFORMITY_PERCENTAGE"
    else
        printf "%30s %s %%\n" "Conformity Percentage :" "N.A" # No check runned, avoid division by 0
    fi
fi
