require 'net/ssh'
require 'aws/ec2'
require 'colorize'
require 'yaml'

# first parameter should be host or list of hosts
exit unless ARGV[0]

def hosts(instance_name)
  instances=[]
  aws = YAML.load_file('config/ec2.yml')
  ec2 = AWS::EC2.new(
      :access_key_id => aws['access_key_id'],
      :secret_access_key => aws['secret_access_key'])
  print "Inspecting instances named #{instance_name}: "
  ec2.instances.each do |instance|
    if instance.tags.to_h['Name'] == instance_name and instance.status == :running
      instances << instance.private_ip_address
      print 'o'.green
    else
      print '.'
    end
  end
  puts 'done'
  puts "#{instances.count} instances found"
  instances
end

instances = hosts ARGV[0]
command = ARGV[1] || "sudo chef-client"
threads = []
instances.each do |host|
  threads << {host: host, thread: Thread.new do
    output = nil
    Net::SSH.start(host, 'ubuntu', :keys => %w(~/.ssh/chef-ec2.pem)) { |ssh| output = ssh.exec!(command) }
    output.to_s
  end}
end

threads.each do |obj|
  puts "[#{obj[:host]}]"
  puts obj[:thread].value
  obj[:thread].join
end