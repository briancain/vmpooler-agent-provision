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

## config file

This script accepts a simple config file for using an existing vmpooler token. It must be called `pooler.yml`. It can look like this, and should be in the same dir as where the script is running from:

```yaml
token: 'exampletokenstring'
```

If no config file exists, it will ask for your username and password and create a token for you.
