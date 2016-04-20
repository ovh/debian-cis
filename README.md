# CIS Debian 7 Hardening

Modular Debian 7 security hardening scripts based on [cisecurity.org](cisecurity.org)
recommendations. We use it at [OVH](https://ovh.com) to harden our PCI-DSS infrastructure.

```console
$ bin/hardening.sh --audit
TODO: some eye catchy output
```

## Quickstart

```console
$ git clone https://github.com/ovh/debian-cis.git && debian-cis
$ some-example-command
```

## Usage

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

Additionally, ``--audit-all`` can be used to force running all auditing scripts,
including disabled ones. this will *not* change the system.

``--audit-all-enable-passed`` can be used as a quick way to kickstart your
configuration. It will run all scripts in audit mode. If a script passes,
it will automatically be enabled for future runs. Do NOT use this option
if you have already started to customize your configuration.

## Hacking

**Getting the source**

```console
git clone https://github.com/ovh/debian-cis.git
```

**Building a debian Package** (the hacky way)

```console
debuild -us -uc
```

**Adding a custom hardening script**

TODO

## Disclaimer

This project is a set of tools. They are meant to help the system administrator
built a secure environment. While we use it at OVH to harden our PCI-DSS compliant
infrastructure, we can not guarantee that it will work for you. It will not
magically secure any random host.

Additionally, quoting the License:

> THIS SOFTWARE IS PROVIDED BY OVH SAS AND CONTRIBUTORS ``AS IS'' AND ANY
> EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
> WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
> DISCLAIMED. IN NO EVENT SHALL OVH SAS AND CONTRIBUTORS BE LIABLE FOR ANY
> DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
> (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
> LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
> ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
> (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
> SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

## Reference

- **Center for Internet Securiy**: https://www.cisecurity.org/
- **CIS recommendations**: https://benchmarks.cisecurity.org/downloads/show-single/index.cfm?file=debian7.100

## License

3-Clause BSD

