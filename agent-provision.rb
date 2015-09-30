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
  centos_vms = body['centos-7-x86_64']
  debian_vms = body['debian-7-x86_64']

  puts  'Centos vms:'
  puts centos_vms

  puts  'Debian vms:'
  puts debian_vms
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
end

if __FILE__ == $0
  token = get_token_from_file
  url = 'https://vcloud.delivery.puppetlabs.net'
  verbose = ENV['VERBOSE'] || false

  if ARGV[0] == 'delete'
    delete_vms(ARGV[1], token, url, verbose)
    exit 0
  end

  os_hash = get_os_hash_from_args(ARGV)

  if os_hash.empty?
    STDERR.puts "You did not supply any arguments"
    STDERR.puts "Example: ruby agent-provision.rb centos-7-x86_64=1 debian-7-x86_64=1"
    exit 1
  end

  if token.nil?
    token = aquire_token(verbose, url)
  end

  hostname_hash = grab_vms(os_hash, token, url, verbose)
  format_os_response(hostname_hash)
  exit 0
end
