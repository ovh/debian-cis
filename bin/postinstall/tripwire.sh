#!/bin/bash

#
# CIS Debian Hardening
#

# If you followed this CIS hardening, this script follows 8.3.1_install_tripwire.sh
# After installing tripwire, you may want to run those few commented commands to make it fully functionnal

echo "Generating Site key file..."
twadmin -m G -S /etc/tripwire/site.key # Generates Site key file
echo "Generating Local key file..."
twadmin -m G -S /etc/tripwire/"$(hostname -f)"-local.key # Generate local key file
echo "Generating encrypted policy..."
twadmin -m P /etc/tripwire/twpol.txt # Apply new policy with generated site key file
echo "Generating Local database with newly created key..."
/usr/sbin/twadmin --create-cfgfile -S /etc/tripwire/site.key /etc/tripwire/twcfg.txt # Init database with generated local key file
echo "Testing tripwire database update"
tripwire -m i # Test configuration update
