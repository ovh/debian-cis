% CIS-HARDENING(8)
%
% 2016

# NAME

cis-hardening - CIS Debian 9/10 Hardening

# SYNOPSIS

**hardening.sh** RUN_MODE [OPTIONS]

# DESCRIPTION

Modular Debian 9/10 security hardening scripts based on the CIS (https://www.cisecurity.org) recommendations.

We use it at OVHcloud (https://www.ovhcloud.com) to harden our PCI-DSS infrastructure.

# SCRIPTS CONFIGURATION

Hardening scripts are in `bin/hardening`. Each script has a corresponding
configuration file in `etc/conf.d/[script_name].cfg`.

Each hardening script can be individually enabled from its configuration file.
For example, this is the default configuration file for `disable_system_accounts`:

```
# Configuration for script of same name
status=disabled
# Put here your exceptions concerning admin accounts shells separated by spaces
EXCEPTIONS=""
```

**status** parameter may take 3 values:

- `disabled` (do nothing): The script will not run.
- `audit` (RO): The script will check if any change should be applied.
- `enabled` (RW): The script will check if any change should be done and automatically apply what it can.

Global configuration is in `etc/hardening.cfg`. This file controls the log level
as well as the backup directory. Whenever a script is instructed to edit a file, it
will create a timestamped backup in this directory.


# RUN MODE

`-h`, `--help`
:   Display a friendly help message.

`--apply`
:   Apply hardening for enabled scripts.
    Beware that NO confirmation is asked whatsoever, which is why you're warmly
    advised to use `--audit` before, which can be regarded as a dry-run mode.

`--audit`
:   Audit configuration for enabled scripts.
    No modification will be made on the system, we'll only report on your system
    compliance for each script.

`--audit-all`
:   Same as `--audit`, but for *all* scripts, even disabled ones.
    This is a good way to peek at your compliance level if all scripts were enabled,
    and might be a good starting point.

`--audit-all-enable-passed`
:   Same as `--audit-all`, but in addition, will *modify* the individual scripts
    configurations to enable those which passed for your system.
    This is an easy way to enable scripts for which you're already compliant.
    However, please always review each activated script afterwards, this option
    should only be regarded as a way to kickstart a configuration from scratch.
    Don't run this if you have already customized the scripts enable/disable
    configurations, obviously.

`--create-config-files-only`
:   Create the config files in etc/conf.d
    Must be run as root, before running the audit with user secaudit

`-set-hardening-level=level`
:   Modifies the configuration to enable/disable tests given an hardening level,
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

`--allow-service=service`
:   Use with `--set-hardening-level`.
    Modifies the policy to allow a certain kind of services on the machine, such
    as http, mail, etc. Can be specified multiple times to allow multiple services.
    Use --allow-service-list to get a list of supported services.

# OPTIONS

`--allow-service-list`
:   Get a list of supported service.

  
`--only test-number`
:    Modifies the RUN_MODE to only work on the test_number script.
    Can be specified multiple times to work only on several scripts.
    The test number is the numbered prefix of the script,
    i.e. the test number of 1.2_script_name.sh is 1.2.

`--sudo`
:   This option lets you audit your system as a normal user, but allows sudo
    escalation to gain read-only access to root files. Note that you need to
    provide a sudoers file with NOPASSWD option in /etc/sudoers.d/ because
    the -n option instructs sudo not to prompt for a password.
    Finally note that `--sudo` mode only works for audit mode.

`--set-log-level=level`
:   This option sets LOGLEVEL, you can choose : info, warning, error, ok, debug.
    Default value is : info

`--batch`
:   While performing system audit, this option sets LOGLEVEL to 'ok' and
    captures all output to print only one line once the check is done, formatted like :
    OK|KO OK|KO|WARN{subcheck results} [OK|KO|WARN{...}]

`--allow-unsupported-distribution`
    Must be specified manually in the command line to allow the run on non compatible
    version or distribution. If you want to mute the warning change the LOGLEVEL
    in /etc/hardening.cfg


# AUTHORS

- Thibault Dewailly, OVHcloud <thibault.dewailly@ovhcloud.com>
- Stéphane Lesimple, OVHcloud <stephane.lesimple@ovhcloud.com>
- Thibault Ayanides, OVHcloud <thibault.ayanides@ovhcloud.com>
- Kevin Tanguy, OVHcloud <kevin.tanguy@ovhcloud.com>

# COPYRIGHT

Copyright 2020 OVHcloud

   Licensed under the Apache License, Version 2.0 (the "License");
   you may not use this file except in compliance with the License.
   You may obtain a copy of the License at

       http://www.apache.org/licenses/LICENSE-2.0

   Unless required by applicable law or agreed to in writing, software
   distributed under the License is distributed on an "AS IS" BASIS,
   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
   See the License for the specific language governing permissions and
   limitations under the License.
# SEE ALSO

- **Center for Internet Security**: https://www.cisecurity.org/
- **CIS recommendations**: https://learn.cisecurity.org/benchmarks
- **Project repository**: https://github.com/ovh/debian-cis

