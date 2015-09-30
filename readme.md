# vmpooler-agent-provision

This script uses [vmfloaty](https://github.com/briancain/vmfloaty) to grab agents from [vmpooler](https://github.com/puppetlabs/vmpooler) and provision them to be used with Puppet Enterprise.

## Example:

Non-verbose:

```
ruby agent-provision.rb centos-7-x86_64=1 debian-7-x86_64=1
```

Verbose:

```
VERBOSE=true ruby agent-provision.rb centos-7-x86_64=1 debian-7-x86_64=1
```
