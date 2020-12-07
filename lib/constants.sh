# shellcheck shell=bash
# Defines constants for CIS Debian Hardening

# run-shellcheck
# Script and shell commands homogeneity
export LANG=C

#### Useful Color constants settings for loglevels

# Reset Color (for syslog)
# shellcheck disable=2034
NC='\033[0m'
# shellcheck disable=2034
WHITE='\033[0m'
# Colors
# shellcheck disable=2034
RED='\033[0;31m'
# shellcheck disable=2034
GREEN='\033[0;32m'
# shellcheck disable=2034
YELLOW='\033[0;33m'
# shellcheck disable=2034
GRAY='\033[0;40m' # Gray

# Bold
# shellcheck disable=2034
BRED='\033[1;31m' # Red
# shellcheck disable=2034
BGREEN='\033[1;32m' # Green
# shellcheck disable=2034
BYELLOW='\033[1;33m' # Yellow
# shellcheck disable=2034
BWHITE='\033[1;37m' # White
