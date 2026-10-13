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
ERROR_CHECKS=0
TOTAL_CHECKS=0
TOTAL_TREATED_CHECKS=0
AUDIT=0
APPLY=0
AUDIT_ALL=0
AUDIT_ALL_ENABLE_PASSED=0
CREATE_CONFIG=0
ALLOW_SERVICE_LIST=0
SET_HARDENING_LEVEL=0
SET_HARDENING_LEVEL_REQUESTED=0
SUDO_MODE=''
BATCH_MODE=''
SUMMARY_JSON=''
ASK_LOGLEVEL=''
ALLOW_UNSUPPORTED_DISTRIBUTION=0
USED_VERSION="default"

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

    --set-version <version>
        This option allows to run the scripts as defined for a specific CIS debian version.
        Supported version are the folders listed in the "versions" folder.
        examples:
          --set-version debian_11
          --set-version ovh_legacy

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

argument_error() {
    printf 'Error: %s\n' "$*" >&2
    exit 2
}

require_value() {
    if [ "$#" -lt 2 ] || [ -z "$2" ] || [[ "$2" == --* ]]; then
        argument_error "$1 requires a value"
    fi
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
        require_value "$@"
        ALLOWED_SERVICES_LIST[${#ALLOWED_SERVICES_LIST[@]}]="$2"
        shift
        ;;
    --set-hardening-level)
        require_value "$@"
        SET_HARDENING_LEVEL="$2"
        SET_HARDENING_LEVEL_REQUESTED=1
        shift
        ;;
    --set-log-level)
        require_value "$@"
        ASK_LOGLEVEL=$2
        shift
        ;;
    --set-version)
        require_value "$@"
        USED_VERSION=$2
        shift
        ;;
    --only)
        require_value "$@"
        [[ "$2" =~ ^[0-9]+(\.[0-9]+)*$ ]] || argument_error "--only expects a numbered check prefix"
        TEST_LIST[${#TEST_LIST[@]}]="$2"_
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
        argument_error "Unknown argument: $ARG"
        ;;
    esac
    shift
done

# Reject contradictory requests before reading or changing configuration.
RUN_MODE_COUNT=$((AUDIT + AUDIT_ALL + AUDIT_ALL_ENABLE_PASSED + APPLY))
if [ "$RUN_MODE_COUNT" -gt 1 ]; then
    argument_error "Select exactly one audit or apply mode"
fi
if [ "$SET_HARDENING_LEVEL_REQUESTED" = 1 ]; then
    [[ "$SET_HARDENING_LEVEL" =~ ^[1-5]$ ]] || argument_error "Hardening level must be between 1 and 5"
fi
if [ "$RUN_MODE_COUNT" -gt 0 ] && { [ "$CREATE_CONFIG" = 1 ] || [ "$SET_HARDENING_LEVEL_REQUESTED" = 1 ] || [ "$ALLOW_SERVICE_LIST" = 1 ]; }; then
    argument_error "Audit/apply modes cannot be combined with configuration modes"
fi
# --create-config-files-only is intentionally compatible with --set-hardening-level;
# the existing engine contract relies on this combination to initialize configs.
if [ "$ALLOW_SERVICE_LIST" = 1 ] && { [ "$CREATE_CONFIG" = 1 ] || [ "$SET_HARDENING_LEVEL_REQUESTED" = 1 ]; }; then
    argument_error "--allow-service-list cannot be combined with configuration changes"
fi
if [ "$RUN_MODE_COUNT" -eq 0 ] && [ "$CREATE_CONFIG" = 0 ] && [ "$SET_HARDENING_LEVEL_REQUESTED" = 0 ] && [ "$ALLOW_SERVICE_LIST" = 0 ]; then
    argument_error "An audit, apply or configuration mode is required"
fi

# --sudo is only meaningful for read-only audit modes. In particular,
# --audit-all-enable-passed writes configuration and must not be accepted here.
if [ -n "$SUDO_MODE" ] && [ "$AUDIT" -eq 0 ] && [ "$AUDIT_ALL" -eq 0 ]; then
    argument_error "--sudo only supports --audit and --audit-all"
fi
if [ -n "$BATCH_MODE" ] && [ -n "$SUMMARY_JSON" ]; then
    argument_error "--batch and --summary-json cannot be combined"
fi
if { [ -n "$BATCH_MODE" ] || [ -n "$SUMMARY_JSON" ]; } && [ "$AUDIT" -eq 0 ] && [ "$AUDIT_ALL" -eq 0 ] && [ "$AUDIT_ALL_ENABLE_PASSED" -eq 0 ]; then
    argument_error "--batch and --summary-json require an audit mode"
fi
if [ "${#ALLOWED_SERVICES_LIST[@]}" -gt 0 ] && [ "$SET_HARDENING_LEVEL_REQUESTED" = 0 ]; then
    argument_error "--allow-service requires --set-hardening-level"
fi
if [ -n "$ASK_LOGLEVEL" ] && [[ ! "$ASK_LOGLEVEL" =~ ^(silent|error|warning|ok|info|debug)$ ]]; then
    argument_error "Unknown log level: $ASK_LOGLEVEL"
fi
if [ "${#TEST_LIST[@]}" -gt 0 ] && { [ "$SET_HARDENING_LEVEL_REQUESTED" = 1 ] || [ "$ALLOW_SERVICE_LIST" = 1 ]; }; then
    argument_error "--only cannot be combined with this configuration mode"
fi

# Source Root Dir Parameter
if [ -r /etc/default/cis-hardening ]; then
    # shellcheck source=../debian/default
    . /etc/default/cis-hardening
fi
if [ -z "$CIS_LIB_DIR" ] || [ -z "${CIS_CONF_DIR}" ] || [ -z "${CIS_CHECKS_DIR}" ]; then
    echo "There is no /etc/default/cis-hardening file nor cis-hardening directory in current environment."
    echo "Cannot source CIS_LIB_DIR, CIS_CONF_DIR, CIS_CHECKS_DIR variables, aborting."
    exit 128
fi

# shellcheck source=../etc/hardening.cfg
[ -r "${CIS_CONF_DIR}"/hardening.cfg ] && . "${CIS_CONF_DIR}"/hardening.cfg
if [ "$ASK_LOGLEVEL" ]; then LOGLEVEL=$ASK_LOGLEVEL; fi
# shellcheck source=../lib/common.sh
[ -r "${CIS_LIB_DIR}"/common.sh ] && . "${CIS_LIB_DIR}"/common.sh
# shellcheck source=../lib/utils.sh
[ -r "${CIS_LIB_DIR}"/utils.sh ] && . "${CIS_LIB_DIR}"/utils.sh
# shellcheck source=../lib/constants.sh
[ -r "${CIS_LIB_DIR}"/constants.sh ] && . "${CIS_LIB_DIR}"/constants.sh

# ensure the CIS version exists
does_file_exist "$CIS_VERSIONS_DIR/$USED_VERSION"
if [ "$FNRET" -ne 0 ]; then
    echo "$USED_VERSION is not a valid version"
    echo "Please use '--set-version' with one of $(ls "$CIS_VERSIONS_DIR" --hide=default -m)"
    exit 1
fi

# If we're on a unsupported platform and there is no flag --allow-unsupported-distribution
# print warning, otherwise quit

# update path for the remaining of the script
CIS_CHECKS_DIR="$CIS_VERSIONS_DIR/$USED_VERSION"

# A typo in --only must not silently produce an empty, successful audit.
for selector in "${TEST_LIST[@]}"; do
    found=0
    while IFS= read -r -d '' SCRIPT; do
        name=${SCRIPT##*/}
        if [ "${name%%_*}_" = "$selector" ]; then
            found=1
            break
        fi
    done < <(find "${CIS_CHECKS_DIR}"/ -name "*.sh" -print0)
    [ "$found" = 1 ] || argument_error "No check matches --only ${selector%_}"
done

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
    if [ "$DEB_MAJ_VER" -gt "$HIGHEST_SUPPORTED_DEBIAN_VERSION" ]; then
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
    while IFS= read -r -d '' SCRIPT; do
        template=$(grep "^HARDENING_EXCEPTION=" "$SCRIPT" | cut -d= -f2)
        [ -n "$template" ] && HARDENING_EXCEPTIONS_LIST[${#HARDENING_EXCEPTIONS_LIST[@]}]="$template"
    done < <(find "${CIS_CHECKS_DIR}"/ -name "*.sh" -print0 | sort -zV)
    echo "Supported services are:" "$(echo "${HARDENING_EXCEPTIONS_LIST[@]}" | tr " " "\n" | sort -u | tr "\n" " ")"
    exit 0
fi

# Keep one canonical status file and ensure the versioned alias exists whenever
# the selected check is reached through a version symlink.
set_script_status() {
    local target name cfg
    target=$(readlink -f -- "$1") || return 1
    name=$(basename "$target" .sh)
    cfg="${CIS_CONF_DIR}/conf.d/$name.cfg"

    # Let main.sh create/repair the canonical configuration and its versioned
    # symlink before editing the canonical status. This also repairs the case
    # where the canonical file exists but the version alias was removed.
    LOGLEVEL=$LOGLEVEL "$1" --create-config-files-only || return 1
    [ -f "$cfg" ] || return 1

    if grep -q '^status=' "$cfg"; then
        sed --follow-symlinks -i -re "s/^status=.*/status=$2/" "$cfg"
    else
        printf '\nstatus=%s\n' "$2" >>"$cfg"
    fi
}

# Select exceptions before writing any configuration, catching misspelled names.
if [ "$SET_HARDENING_LEVEL_REQUESTED" = 1 ]; then
    declare -a KNOWN_SERVICES=()
    while IFS= read -r -d '' SCRIPT; do
        template=$(sed -n 's/^HARDENING_EXCEPTION=//p' "$SCRIPT")
        [ -z "$template" ] || KNOWN_SERVICES+=("$template")
    done < <(find "${CIS_CHECKS_DIR}"/ -name "*.sh" -print0 | sort -zV)
    for service in "${ALLOWED_SERVICES_LIST[@]}"; do
        found=0
        for template in "${KNOWN_SERVICES[@]}"; do
            [ "$service" != "$template" ] || found=1
        done
        [ "$found" = 1 ] || argument_error "Unknown service exception: $service"
    done
    while IFS= read -r -d '' SCRIPT; do
        script_level=$(grep '^HARDENING_LEVEL=' "$SCRIPT" | cut -d= -f2)
        if [[ ! "$script_level" =~ ^[1-5]$ ]]; then
            printf 'Invalid or missing hardening level: %s\n' "$SCRIPT" >&2
            exit 1
        fi
        wantedstatus=disabled
        [ "$script_level" -gt "$SET_HARDENING_LEVEL" ] || wantedstatus=enabled
        template=$(sed -n 's/^HARDENING_EXCEPTION=//p' "$SCRIPT")
        for service in "${ALLOWED_SERVICES_LIST[@]}"; do
            [ "$service" != "$template" ] || wantedstatus=disabled
        done
        if ! set_script_status "$SCRIPT" "$wantedstatus"; then
            printf 'Cannot update configuration for %s\n' "$SCRIPT" >&2
            exit 1
        fi
    done < <(find "${CIS_CHECKS_DIR}"/ -name "*.sh" -print0 | sort -zV)
    echo "Configuration modified to enable scripts at or below the selected level, except allowed services"
    exit 0
fi

if [ "$CREATE_CONFIG" = 1 ] && [ "$EUID" -ne 0 ]; then
    echo "For --create-config-files-only, please run as root"
    exit 1
fi

# Parse every scripts and execute them in the required mode
while IFS= read -r -d '' SCRIPT; do
    if [ "${#TEST_LIST[@]}" -gt 0 ]; then
        # --only X has been specified at least once, is this script in my list ?
        SCRIPT_PREFIX=$(grep -Eo '^[0-9.]+' <<<"$(basename "$SCRIPT")")
        # shellcheck disable=SC2001
        SCRIPT_PREFIX_RE=$(sed -e 's/\./\\./g' <<<"$SCRIPT_PREFIX")
        SCRIPT_PREFIX_RE="$SCRIPT_PREFIX_RE"_
        if ! grep -qE "(^|[[:space:]])$SCRIPT_PREFIX_RE([[:space:]]|$)" <<<"${TEST_LIST[@]}"; then
            # not in the list
            continue
        fi
    fi

    info "Treating $SCRIPT"
    if [ "$CREATE_CONFIG" = 1 ]; then
        debug "$SCRIPT --create-config-files-only"
        LOGLEVEL=$LOGLEVEL "$SCRIPT" --create-config-files-only "$BATCH_MODE"
    elif [ "$AUDIT" = 1 ]; then
        debug "$SCRIPT --audit $SUDO_MODE $BATCH_MODE"
        LOGLEVEL=$LOGLEVEL "$SCRIPT" --audit "$SUDO_MODE" "$BATCH_MODE"
    elif [ "$AUDIT_ALL" = 1 ]; then
        debug "$SCRIPT --audit-all $SUDO_MODE $BATCH_MODE"
        LOGLEVEL=$LOGLEVEL "$SCRIPT" --audit-all "$SUDO_MODE" "$BATCH_MODE"
    elif [ "$AUDIT_ALL_ENABLE_PASSED" = 1 ]; then
        debug "$SCRIPT --audit-all $SUDO_MODE $BATCH_MODE"
        LOGLEVEL=$LOGLEVEL "$SCRIPT" --audit-all "$SUDO_MODE" "$BATCH_MODE"
    elif [ "$APPLY" = 1 ]; then
        debug "$SCRIPT"
        LOGLEVEL=$LOGLEVEL "$SCRIPT"
    fi

    SCRIPT_EXITCODE=$?

    debug "Script $SCRIPT finished with exit code $SCRIPT_EXITCODE"
    case $SCRIPT_EXITCODE in
    0)
        debug "$SCRIPT passed"
        PASSED_CHECKS=$((PASSED_CHECKS + 1))
        if [ "$AUDIT_ALL_ENABLE_PASSED" = 1 ]; then
            if set_script_status "$SCRIPT" enabled; then
                info "Status set to enabled for $SCRIPT"
            else
                printf 'Cannot enable configuration for %s\n' "$SCRIPT" >&2
                ERROR_CHECKS=$((ERROR_CHECKS + 1))
            fi
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
    *)
        printf 'Check %s exited unexpectedly with status %s\n' "$SCRIPT" "$SCRIPT_EXITCODE" >&2
        ERROR_CHECKS=$((ERROR_CHECKS + 1))
        ;;
    esac

    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))

done < <(find "${CIS_CHECKS_DIR}"/ -name "*.sh" -print0 | sort -zV)

TOTAL_TREATED_CHECKS=$((TOTAL_CHECKS - DISABLED_CHECKS))

if [ "$BATCH_MODE" ]; then
    BATCH_SUMMARY="AUDIT_SUMMARY "
    BATCH_SUMMARY+="PASSED_CHECKS:${PASSED_CHECKS:-0} "
    BATCH_SUMMARY+="RUN_CHECKS:${TOTAL_TREATED_CHECKS:-0} "
    BATCH_SUMMARY+="TOTAL_CHECKS_AVAIL:${TOTAL_CHECKS:-0} "
    BATCH_SUMMARY+="ERROR_CHECKS:${ERROR_CHECKS:-0}"
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
    printf '"failed_checks": %s, ' "$FAILED_CHECKS"
    printf '"error_checks": %s, ' "$ERROR_CHECKS"
    printf '"conformity_percentage": %s' "$CONFORMITY_PERCENTAGE"
    printf '}\n'
else
    printf "%40s\n" "################### SUMMARY ###################"
    printf "%30s %s\n" "Total Available Checks :" "$TOTAL_CHECKS"
    printf "%30s %s\n" "Total Runned Checks :" "$TOTAL_TREATED_CHECKS"
    printf "%30s [ %7s ]\n" "Total Passed Checks :" "$PASSED_CHECKS/$TOTAL_TREATED_CHECKS"
    printf "%30s [ %7s ]\n" "Total Failed Checks :" "$FAILED_CHECKS/$TOTAL_TREATED_CHECKS"

    printf "%30s %s\n" "Execution Errors :" "$ERROR_CHECKS"

    ENABLED_CHECKS_PERCENTAGE=$(div $((TOTAL_TREATED_CHECKS * 100)) $TOTAL_CHECKS)
    CONFORMITY_PERCENTAGE=$(div $((PASSED_CHECKS * 100)) $TOTAL_TREATED_CHECKS)
    printf "%30s %s %%\n" "Enabled Checks Percentage :" "$ENABLED_CHECKS_PERCENTAGE"
    if [ "$TOTAL_TREATED_CHECKS" != 0 ]; then
        printf "%30s %s %%\n" "Conformity Percentage :" "$CONFORMITY_PERCENTAGE"
    else
        printf "%30s %s %%\n" "Conformity Percentage :" "N.A" # No check runned, avoid division by 0
    fi
fi

# Preserve the historical status for completed audits, but never hide execution errors.
if [ "$ERROR_CHECKS" -gt 0 ]; then
    exit 3
fi
