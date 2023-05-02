# :lock: CIS Debian 10/11 Hardening


<p align="center">
      <img src="https://repository-images.githubusercontent.com/56690366/bbe7c380-55b2-11eb-84ba-d06bf153fe8b" width="300px">
</p>

![Shell-linter](https://github.com/ovh/debian-cis/workflows/Run%20shell-linter/badge.svg)
![Functionnal tests](https://github.com/ovh/debian-cis/workflows/Run%20functionnal%20tests/badge.svg)
![Release](https://github.com/ovh/debian-cis/workflows/Create%20Release/badge.svg)

![Realease](https://img.shields.io/github/v/release/ovh/debian-cis)
![License](https://img.shields.io/github/license/ovh/debian-cis)
---

Modular Debian 10/11 security hardening scripts based on [cisecurity.org](https://www.cisecurity.org)
recommendations. We use it at [OVHcloud](https://www.ovhcloud.com) to harden our PCI-DSS infrastructure.

```console
$ bin/hardening.sh --audit-all
[...]
hardening [INFO] Treating /opt/cis-hardening/bin/hardening/6.2.19_check_duplicate_groupname.sh
6.2.19_check_duplicate_gr [INFO] Working on 6.2.19_check_duplicate_groupname
6.2.19_check_duplicate_gr [INFO] Checking Configuration
6.2.19_check_duplicate_gr [INFO] Performing audit
6.2.19_check_duplicate_gr [ OK ] No duplicate GIDs
6.2.19_check_duplicate_gr [ OK ] Check Passed
[...]
################### SUMMARY ###################
      Total Available Checks : 232
         Total Runned Checks : 166
         Total Passed Checks : [ 142/166 ]
         Total Failed Checks : [  24/166 ]
   Enabled Checks Percentage : 71.00 %
       Conformity Percentage : 85.00 %
```

## :dizzy: Quickstart

```console
$ git clone https://github.com/ovh/debian-cis.git && cd debian-cis
$ cp debian/default /etc/default/cis-hardening
$ sed -i "s#CIS_ROOT_DIR=.*#CIS_ROOT_DIR='$(pwd)'#" /etc/default/cis-hardening
$ bin/hardening/1.1.1.1_disable_freevxfs.sh --audit-all
hardening                 [INFO] Treating /opt/cis-hardening/bin/hardening/1.1.1.1_disable_freevxfs.sh
1.1.1.1_disable_freevxfs  [INFO] Working on 1.1.1.1_disable_freevxfs
1.1.1.1_disable_freevxfs  [INFO] [DESCRIPTION] Disable mounting of freevxfs filesystems.
1.1.1.1_disable_freevxfs  [INFO] Checking Configuration
1.1.1.1_disable_freevxfs  [INFO] Performing audit
1.1.1.1_disable_freevxfs  [ OK ] CONFIG_VXFS_FS is disabled
1.1.1.1_disable_freevxfs  [ OK ] Check Passed
```

## :hammer: Usage

### Configuration

Hardening scripts are in ``bin/hardening``. Each script has a corresponding
configuration file in ``etc/conf.d/[script_name].cfg``.

Each hardening script can be individually enabled from its configuration file.
For example, this is the default configuration file for ``disable_system_accounts``:

```
# Configuration for script of same name
status=disabled
# Put here your exceptions concerning admin accounts shells separated by spaces
EXCEPTIONS=""
```

``status`` parameter may take 3 values:
- ``disabled`` (do nothing): The script will not run.
- ``audit`` (RO): The script will check if any change *should* be applied.
- ``enabled`` (RW): The script will check if any change should be done and automatically apply what it can.

Global configuration is in ``etc/hardening.cfg``. This file controls the log level
as well as the backup directory. Whenever a script is instructed to edit a file, it
will create a timestamped backup in this directory.

### Run aka "Harden your distro"

To run the checks and apply the fixes, run ``bin/hardening.sh``.

This command has 2 main operation modes:
- ``--audit``: Audit your system with all enabled and audit mode scripts
- ``--apply``: Audit your system with all enabled and audit mode scripts and apply changes for enabled scripts

Additionally, some options add more granularity:

 ``--audit-all`` can be used to force running all auditing scripts,
including disabled ones. this will *not* change the system.

``--audit-all-enable-passed`` can be used as a quick way to kickstart your
configuration. It will run all scripts in audit mode. If a script passes,
it will automatically be enabled for future runs. Do NOT use this option
if you have already started to customize your configuration.

``--sudo``: audit your system as a normal user, but allow sudo escalation to read
specific root read-only files. You need to provide a sudoers file in /etc/sudoers.d/
with NOPASWD option, since checks are executed with ``sudo -n`` option, that will
not prompt for a password.

``--batch``: while performing system audit, this option sets LOGLEVEL to 'ok' and
captures all output to print only one line once the check is done, formatted like :
OK|KO OK|KO|WARN{subcheck results} [OK|KO|WARN{...}]

``--only <check_number>``: run only the selected checks.

``--set-hardening-level``: run all checks that are lower or equal to the selected level.
Do NOT use this option if you have already started to customize your configuration.

``--allow-service <service>``: use with --set-hardening-level. Modifies the policy 
to allow a certain kind of services on the machine, such as http, mail, etc.
Can be specified multiple times to allow multiple services.
Use --allow-service-list to get a list of supported services.

``--set-log-level <level>``: This option sets LOGLEVEL, you can choose : info, warning, error, ok, debug.
Default value is : info

``--create-config-files-only``: create the config files in etc/conf.d. Must be run as root,
before running the audit with user secaudit, to have the rights setup well on the conf files.

``--allow-unsupported-distribution``: must be specified manually in the command line to allow 
the run on non compatible version or distribution. If you want to mute the warning change the
LOGLEVEL in /etc/hardening.cfg

## :computer: Hacking

**Getting the source**

```console
$ git clone https://github.com/ovh/debian-cis.git
```

**Building a debian Package** (the hacky way)

```console
$ debuild -us -uc
```

**Adding a custom hardening script**

```console
$ cp src/skel bin/hardening/99.99_custom_script.sh
$ chmod +x bin/hardening/99.99_custom_script.sh
$ cp src/skel.cfg etc/conf.d/99.99_custom_script.cfg
```
Every custom check numerotation begins with 99. The numbering after it depends on the section the check refers to.

If the check replace somehow one that is in the CIS specifications,
you can use the numerotation of the check it replaces inplace. For example we check
the config of OSSEC (file integrity) in `1.4.x` whereas CIS recommends AIDE.

Do not forget to specify in comment if it's a bonus check (suggested by CIS but not in the CIS numerotation), a legacy check (part from previous CIS specification but deleted in more recents one) or an OVHcloud security check.
(part of OVHcloud security policy)


Code your check explaining what it does then if you want to test

```console
$ sed -i "s/status=.+/status=enabled/" etc/conf.d/99.99_custom_script.cfg
$ ./bin/hardening/99.99_custom_script.sh
```
## :sparkles: Functional testing

Functional tests are available. They are to be run in a Docker environment.

```console
$ ./tests/docker_build_and_run_tests.sh <target> [name of test script...]
```

With `target` being like `debian10` or `debian11`.

Running without script arguments will run all tests in `./tests/hardening/` directory.
Or you can specify one or several test script to be run.

This will build a new Docker image from the current state of the projet and run
a container that will assess a blank Debian system compliance for each check.  
For hardening audit points the audit is expected to fail, then be fixed so that
running the audit a second time will succeed.  
For vulnerable items, the audit is expected to succeed on a blank
system, then the functional tests will introduce a weak point, that is expected
to be detected when running the audit test a second time. Finally running the `apply`
part of debian-cis script will restore a compliance state that is expected to be
assed by running the audit check a third time.

Functional tests can make use of the following helper functions :  

* `describe <test description>`
* `run <usecase> <audit_script> <audit_script_options>`
* `register_test <test content (see below)>`
  * `retvalshoudbe <integer>` check the script return value
  * `contain "<SAMPLE TEXT>"` check that the output contains the following text

In order to write your own functional test, you will find a code skeleton in
`./src/skel.test`.

Some tests ar labelled with a disclaimer warning that we only test on a blank host
and that we will not test the apply function. It's because the check is very basic
(like a package install) and that a test on it is not really necessary.

Furthermore, some tests are disabled on docker because there not pertinent (kernel 
modules, grub, partitions, ...)
You can disable a check on docker with:
```bash
if [ -f "/.dockerenv" ]; then
  skip "SKIPPED on docker"
else
...
fi
```

## :art: Coding style
### Shellcheck

We use [Shellcheck](https://github.com/koalaman/shellcheck) to check the 
correctness of the scripts and to respect best practices.
It can be used directly with the docker environnment to check all scripts 
compliancy. By default it runs on every `.sh` it founds.

```console
$ ./shellcheck/launch_shellcheck.sh [name of script...]
```

### Shellfmt

We use [Shellfmt](https://github.com/mvdan/sh) to check the styling and to keep a 
consistent style in every script. 
Identically to shellcheck, it can be run through a script with the following:

```console
$ ./shellfmt/launch_shellfmt.sh
```
It will automatically fix any styling problem on every script.


## :heavy_exclamation_mark: Disclaimer

This project is a set of tools. They are meant to help the system administrator
built a secure environment. While we use it at OVHcloud to harden our PCI-DSS compliant
infrastructure, we can not guarantee that it will work for you. It will not
magically secure any random host.

Additionally, quoting the License:

> THIS SOFTWARE IS PROVIDED BY OVH SAS AND CONTRIBUTORS ``AS IS'' AND ANY
> EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
> WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
> DISCLAIMED. IN NO EVENT SHALL OVHcloud SAS AND CONTRIBUTORS BE LIABLE FOR ANY
> DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
> (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
> LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
> ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
> (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
> SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

## :satellite: Reference

- **Center for Internet Security**: https://www.cisecurity.org/
- **CIS recommendations**: https://learn.cisecurity.org/benchmarks

## :page_facing_up: License

Apache, Version 2.0
