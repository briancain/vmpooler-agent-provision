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

def format_os_response(body)
  host_list = Array.new

  centos_hosts = body['centos-7-x86_64']
  debian_hosts = body['debian-7-x86_64']

  centos_hosts.each do |key,host_arr|
    if host_arr.kind_of?(Array)
      host_arr.each do |host|
        host_list.push host
      end
    else
      host_list.push host_arr
    end
  end

  debian_hosts.each do |key,host_arr|
    if host_arr.kind_of?(Array)
      host_arr.each do |host|
        host_list.push host
      end
    else
      host_list.push host_arr
    end
  end

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
  STDOUT.flush
  puts "Enter 'root' password for all vms (by default all pooler vms share the same password):"
  password = STDIN.noecho(&:gets).chomp
  user = 'root'
  # run this command on hosts to register them with puppet master
  add_node_cmd = "curl -k https://#{pe_master}:8140/packages/current/install.bash | bash"
  # run puppet
  run_puppet = "/opt/puppetlabs/puppet/bin/puppet agent -t"


  host_list.each do |host|
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
    STDERR.puts "Example: PEMASTER=mymasterhost.net ruby agent-provision.rb centos-7-x86_64=1 debian-7-x86_64=1"
  end

  os_hash = get_os_hash_from_args(ARGV)

  if os_hash.empty?
    STDERR.puts "You did not supply any arguments"
    STDERR.puts "Example: PEMASTER=mymasterhost.net ruby agent-provision.rb centos-7-x86_64=1 debian-7-x86_64=1"
    exit 1
  end

  if token.nil?
    token = aquire_token(verbose, url)
  end

  hostname_hash = grab_vms(os_hash, token, url, verbose)
  host_list = format_os_response(hostname_hash)
  puts host_list
  provision_hosts(pe_master, host_list)
  exit 0
end
