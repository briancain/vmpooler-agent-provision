# vmpooler-agent-provision

This script uses [vmfloaty](https://github.com/briancain/vmfloaty) to grab agents from [vmpooler](https://github.com/puppetlabs/vmpooler) and provision them to be used with Puppet Enterprise.

_NOTE:_ This was written for a demo, so it may break in the future

## Grabbing and provisioning vms example:

Non-verbose:

```
PEMASTER=myhost.delivery.puppetlabs.net ruby agent-provision.rb centos-7-x86_64=1 debian-7-x86_64=1
```

Verbose:

```
PEMASTER=myhost.delivery.puppetlabs.net VERBOSE=true ruby agent-provision.rb centos-7-x86_64=1 debian-7-x86_64=1
```

## Deleting vms

```
ruby agent-provision.rb delete qtznen7fe1hclk1,uw320rq6tgu6j89
```

## config file

This script accepts a simple config file for using an existing vmpooler token. It must be called `pooler.yml`. It can look like this, and should be in the same dir as where the script is running from:

```yaml
token: 'exampletokenstring'
```

If no config file exists, it will ask for your username and password and create a token for you and save it in the current directory as `pooler.yml`.

## Assumptions

This script makes a couple assumptions about your puppet master

### Auto signing

This script assumes that your master will autosign new agents. You can enable this by running the command below on your PE Master.

```
/opt/puppetlabs/bin/puppet config set autosign true --section master
```

### Debian Packages

It also assumes that your master has the proper debian packages in the PE Master class. The easiest way to do this is to run this simple ruby script below on your master:

```ruby
pe_hostname = `facter fqdn`.strip
require 'puppetclassify'

# URL of classifier as well as certificates and private key for auth
auth_info = {
  "ca_certificate_path" => "/etc/puppetlabs/puppet/ssl/certs/ca.pem",
  "certificate_path"    => "/etc/puppetlabs/puppet/ssl/certs/#{pe_hostname}.pem",
  "private_key_path"    => "/etc/puppetlabs/puppet/ssl/private_keys/#{pe_hostname}.pem"
}

classifier_url = "https://#{pe_hostname}:4433/classifier-api"
puppetclassify = PuppetClassify.new(classifier_url, auth_info)

master_id = puppetclassify.groups.get_group_id("PE Master")
group_delta = {"name"=>"PE Master", "id"=>master_id, "environment"=>"production", "classes"=>{"pe_repo::platform::debian_7_amd64"=>{}}}
puppetclassify.groups.update_group(group_delta)
```

Then rerun `puppet agent -t` on your master

### Other assumptions

Since this is a script for a demo, it assumes that you only will request centos-7 and debian-7 vms.

## Deleting your token

If you would like to remove your token from use, simply use the floaty cli to remove the token:

```
floaty token delete --token mytokenstring --url https://vcloud.delivery.puppetlabs.net --user username
```
