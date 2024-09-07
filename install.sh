#!/bin/bash

# Made By Taylor Christian Newsome

# Ensure we run as root
if [ "$(id -u)" -ne "0" ]; then
  echo "This script must be run as root."
  exit 1
fi

# Define variables
REPO_URL="https://github.com/ovh/debian-cis.git"
REPO_DIR="/opt/debian-cis"
DEFAULT_CONFIG="/etc/default/cis-hardening"
LOG_FILE="/var/log/debian-cis-hardening.log"

# Log function
log() {
  local msg="$1"
  echo "$(date '+%Y-%m-%d %H:%M:%S') - $msg" >> "$LOG_FILE"
}

# Initialize log file
if [ ! -f "$LOG_FILE" ]; then
  touch "$LOG_FILE"
  chmod 600 "$LOG_FILE"
  log "Log file created."
fi

# Clone the repository if not already present
if [ ! -d "$REPO_DIR" ]; then
  log "Cloning the debian-cis repository..."
  git clone "$REPO_URL" "$REPO_DIR" >> "$LOG_FILE" 2>&1
  if [ $? -ne 0 ]; then
    log "Failed to clone repository."
    exit 1
  fi
else
  log "Repository already cloned."
fi

cd "$REPO_DIR" || exit

# Copy default configuration
if [ -f "$DEFAULT_CONFIG" ]; then
  log "$DEFAULT_CONFIG already exists. Backing up..."
  cp "$DEFAULT_CONFIG" "$DEFAULT_CONFIG.bak"
  if [ $? -ne 0 ]; then
    log "Failed to back up default configuration."
    exit 1
  fi
fi
cp debian/default "$DEFAULT_CONFIG"
if [ $? -ne 0 ]; then
  log "Failed to copy default configuration."
  exit 1
fi

# Update configuration with the repository paths
log "Updating configuration paths..."
sed -i "s#CIS_LIB_DIR=.*#CIS_LIB_DIR='$(pwd)'/lib#" "$DEFAULT_CONFIG"
sed -i "s#CIS_CHECKS_DIR=.*#CIS_CHECKS_DIR='$(pwd)'/bin/hardening#" "$DEFAULT_CONFIG"
sed -i "s#CIS_CONF_DIR=.*#CIS_CONF_DIR='$(pwd)'/etc#" "$DEFAULT_CONFIG"
sed -i "s#CIS_TMP_DIR=.*#CIS_TMP_DIR='$(pwd)'/tmp#" "$DEFAULT_CONFIG"

# Run full audit
log "Running full audit with all available checks..."
./bin/hardening.sh --audit-all >> "$LOG_FILE" 2>&1
if [ $? -ne 0 ]; then
  log "Full audit failed."
  exit 1
fi

# Perform specific script audit
log "Running audit for specific script: 1.1.1.1_disable_freevxfs.sh..."
./bin/hardening/1.1.1.1_disable_freevxfs.sh --audit >> "$LOG_FILE" 2>&1
if [ $? -ne 0 ]; then
  log "Specific script audit failed."
  exit 1
fi

# Additional audit options
echo "Choose additional audit options (press Enter to skip):"
echo "1. Audit all checks and enable passing checks"
echo "2. Audit with sudo escalation"
echo "3. Audit specific check number"
echo "4. Set hardening level"
echo "5. Allow specific services"
read -r OPTION

case $OPTION in
  1)
    log "Running audit with all checks and enabling passing checks..."
    ./bin/hardening.sh --audit-all-enable-passed >> "$LOG_FILE" 2>&1
    if [ $? -ne 0 ]; then
      log "Audit with all checks and enabling passing checks failed."
      exit 1
    fi
    ;;
  2)
    log "Running audit with sudo escalation..."
    ./bin/hardening.sh --sudo >> "$LOG_FILE" 2>&1
    if [ $? -ne 0 ]; then
      log "Audit with sudo escalation failed."
      exit 1
    fi
    ;;
  3)
    echo "Enter the specific check number:"
    read -r CHECK_NUMBER
    log "Running audit for check number $CHECK_NUMBER..."
    ./bin/hardening.sh --only "$CHECK_NUMBER" >> "$LOG_FILE" 2>&1
    if [ $? -ne 0 ]; then
      log "Audit for check number $CHECK_NUMBER failed."
      exit 1
    fi
    ;;
  4)
    echo "Enter the hardening level (e.g., 2 for level 2):"
    read -r HARDENING_LEVEL
    log "Running audit with hardening level $HARDENING_LEVEL..."
    ./bin/hardening.sh --set-hardening-level "$HARDENING_LEVEL" >> "$LOG_FILE" 2>&1
    if [ $? -ne 0 ]; then
      log "Audit with hardening level $HARDENING_LEVEL failed."
      exit 1
    fi
    ;;
  5)
    echo "Enter services to allow (e.g., http mail):"
    read -r ALLOWED_SERVICES
    log "Running audit with allowed services: $ALLOWED_SERVICES..."
    ./bin/hardening.sh --set-hardening-level 2 --allow-service "$ALLOWED_SERVICES" >> "$LOG_FILE" 2>&1
    if [ $? -ne 0 ]; then
      log "Audit with allowed services $ALLOWED_SERVICES failed."
      exit 1
    fi
    ;;
  *)
    log "No additional options selected."
    ;;
esac

# Apply changes if selected
echo "Would you like to apply changes for all enabled checks? (y/n)"
read -r APPLY_CHANGES
if [ "$APPLY_CHANGES" = "y" ]; then
  log "Applying changes for all enabled checks..."
  ./bin/hardening.sh --apply >> "$LOG_FILE" 2>&1
  if [ $? -ne 0 ]; then
    log "Applying changes failed."
    exit 1
  fi
fi

log "Configuration and audit setup complete."
