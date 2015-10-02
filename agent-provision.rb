require 'vmfloaty/pooler'
require 'vmfloaty/auth'
require 'io/console'
require 'yaml'
require 'net/ssh'

def aquire_token(verbose, url)
  STDOUT.flush
  puts "Enter username:"
  user = $stdin.gets.chomp
  puts "Enter password:"
  password = STDIN.noecho(&:gets).chomp
  token = Auth.get_token(verbose, url, user, password)

  puts "Your token:\n#{token}"
  puts "Saving this token to the current dir in pooler.yml"
  save_token(token)

  token
end

def save_token(token)
  begin
    File.open("#{Dir.pwd}/pooler.yml", 'w') { |file| file.write("token: #{token}\n") }
  rescue
    STDERR.puts "There was a problem writing your token file..."
    exit 1
  end
end

def get_os_hash_from_args(argv)
  os_hash = {}
  argv.each do |arg|
    os_arr = arg.split("=")
    os_hash[os_arr[0]] = os_arr[1].to_i
  end

  os_hash
end

def build_list(hostname_hash)
  host_list = Array.new

  if hostname_hash.kind_of?(Array)
    hostname_hash.each do |host|
      host_list.push host
    end
  else
    host_list.push hostname_hash
  end

  host_list
end

def format_os_response(body)
  linux_host_list = Array.new
  windows_host_list = Array.new
  host_list = {}

  centos_hosts = body['centos-7-x86_64']['hostname'] unless body['centos-7-x86_64'].nil?
  debian_hosts = body['debian-7-x86_64']['hostname'] unless body['debian-7-x86_64'].nil?
  windows_hosts = body['win-2012r2-x86_64']['hostname'] unless body['win-2012r2-x86_64'].nil?

  unless centos_hosts.nil?
    centos_list = build_list(centos_hosts)
    centos_list.each do |host|
      linux_host_list.push host
    end
  end

  unless debian_hosts.nil?
    debian_list = build_list(debian_hosts)
    debian_list.each do |host|
      linux_host_list.push host
    end
  end

  windows_host_list = build_list(windows_hosts) unless windows_hosts.nil?

  host_list['linux'] = linux_host_list
  host_list['windows'] = windows_host_list
  host_list
end

def grab_vms(os_hash, token, url, verbose)
  os_string = ""

  ## Because the Pooler.retrieve command
  #  expects this to be directly from the command line
  #  delimited by commas
  os_hash.each do |os,num|
    num.times do |i|
      os_string << os+","
    end
  end

  os_string = os_string.chomp(",")
  response_body = Pooler.retrieve(verbose, os_string, token, url)

  if response_body['ok'] == false
    STDERR.puts "There was a problem with your request"
    exit 1
  end

  response_body
end

def delete_vms(hostnames, token, url, verbose)
  Pooler.delete(verbose, url, hostnames, token)
end

def get_token_from_file
  conf = {}
  token = ''

  begin
    conf = YAML.load_file("#{Dir.pwd}/pooler.yml")
  rescue
    STDERR.puts "There was no config file to read from"
  end

  token = conf['token']
  token
end

def provision_hosts(pe_master, host_list)
  linux_hosts = host_list['linux']
  windows_hosts = host_list['windows']

  STDOUT.flush
  puts "Enter 'root' password for all vms (by default all pooler vms share the same password):"
  password = STDIN.noecho(&:gets).chomp
  user = 'root'
  # run this command on hosts to register them with puppet master
  add_node_cmd = "curl -k https://#{pe_master}:8140/packages/current/install.bash | bash"
  # run puppet
  run_puppet = "/opt/puppetlabs/puppet/bin/puppet agent -t"


  # windows
  win_user = 'Administrator'
  get_puppet_agent = "curl -O http://agent-downloads.delivery.puppetlabs.net/2015.3/puppet-agent-latest/repos/windows/puppet-agent-1.2.5.139.g5822f8d-x64.msi"
  add_win_node_cmd = "cmd.exe /c \"start /w msiexec /qn /L*V install.txt /i puppet-agent-1.2.5.139.g5822f8d-x64.msi PUPPET_MASTER_SERVER=#{pe_master} PUPPET_AGENT_STARTUP_MODE=Manual\""
  run_puppet_win = "cd /cygdrive/c/Program\\ Files/Puppet\\ Labs/Puppet/bin/ && cmd /c puppet.bat agent -t"

  linux_hosts.each do |host|
    begin
      ssh = Net::SSH.start(host, user, :password => password)
      puts "Setting up agent packages on host #{host}"
      setup_res = ssh.exec!(add_node_cmd)
      puts setup_res
      puts "Running puppet on host #{host}"
      agent_run_res = ssh.exec!(run_puppet)
      puts agent_run_res
      ssh.close
    rescue
      STDERR.puts "Unable to connect to #{host} using #{user}"
      exit 1
    end
  end

  windows_hosts.each do |host|
    begin
      ssh = Net::SSH.start(host, win_user, :password => password)
      puts 'Getting puppet-agent package'
      get_package = ssh.exec!(get_puppet_agent)
      puts get_package
      puts "Setting up agent packages on host #{host}"
      setup_res = ssh.exec!(add_win_node_cmd)
      puts setup_res
      puts "Running puppet on host #{host}"
      agent_run_res = ssh.exec!(run_puppet_win)
      puts agent_run_res
      ssh.close
    rescue
      STDERR.puts "Unable to connect to #{host} using #{user}"
      exit 1
    end
  end
end

if __FILE__ == $0
  token = get_token_from_file
  url = 'https://vcloud.delivery.puppetlabs.net'
  verbose = ENV['VERBOSE'] || false
  pe_master = ENV['PEMASTER']


  if ARGV[0] == 'delete'
    delete_vms(ARGV[1], token, url, verbose)
    exit 0
  end

  if pe_master.nil?
    STDERR.puts "You did not set the PEMASTER env var"
    STDERR.puts "Example: PEMASTER=mymasterhost.net ruby agent-provision.rb centos-7-x86_64=1 debian-7-x86_64=1 win-2012r2-x86_64=1"
  end

  os_hash = get_os_hash_from_args(ARGV)

  if os_hash.empty?
    STDERR.puts "You did not supply any arguments"
    STDERR.puts "Example: PEMASTER=mymasterhost.net ruby agent-provision.rb centos-7-x86_64=1 debian-7-x86_64=1 win-2012r2-x86_64=1"
    exit 1
  end

  if token.nil?
    token = aquire_token(verbose, url)
  end

  hostname_hash = grab_vms(os_hash, token, url, verbose)
  host_list = format_os_response(hostname_hash)

  puts "Your hosts:"
  puts host_list

  provision_hosts(pe_master, host_list)
  exit 0
end
