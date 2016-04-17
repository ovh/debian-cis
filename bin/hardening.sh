#!/bin/bash

# CIs Deb
#
# CIS Debian 7 Hardening
# Authors : Thibault Dewailly, OVH <thibault.dewailly@corp.ovh.com>
#

#
# Main script : Execute hardening considering configuration
#

# Execute blindly binaries
# Audit mode

# ls | sort -V

cd /opt/cis-hardening/bin/hardening
for i in $(ls | sort -V); do 
echo "$i"
./$i --audit
done
