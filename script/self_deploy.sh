#!/bin/bash

############################################################################
#
# hypermindR api - worker self deploy script
# this script is downloaded from S3 and run on every worker machine
# it is called by /code/self_deploy.sh upon startup (usually on an
# autoscaling scenario). It is run with sudo.
#
# to update the S3 version of this script, run the following command from
# the project root:
# $ ROLES=app_primary cap peixe deploy:upload_self_deploy
#
###########################################################################


# run chef-client #########################################################

## mv /etc/chef/client.pem /etc/chef/client.pem.bak
##
## # define a function for later use
## function getmeta() {
##   wget -qO- http://169.254.169.254/latest$1
## }
##
## # get EC2 meta-data
## env='prod'
## role='peixe-worker'
##
## hostname="$(getmeta /meta-data/instance-id)"
##
## # write first-boot.json to be used by the chef-client command.
## # this sets the ROLE of the node.
## echo -e "{\"run_list\": [\"role[$role]\"]}" > /etc/chef/first-boot.json
##
## # write client.rb
## # this sets the ENVIRONMENT of the node, along with some basics.
## > /etc/chef/client.rb
## echo -e "log_level               :info" >> /etc/chef/client.rb
## echo -e "log_location            '/var/log/chef-client.log'" >> /etc/chef/client.rb
## echo -e "chef_server_url         'https://chef.hypermindr.com'" >> /etc/chef/client.rb
## echo -e "validation_client_name  'chef-validator'" >> /etc/chef/client.rb
## echo -e "environment             '$env'" >> /etc/chef/client.rb
## echo -e "node_name               '$hostname'" >> /etc/chef/client.rb
##
## # append the node FQDN to knife.fb
## echo -e "node_name               '$hostname'" >> /etc/chef/knife.rb
##
## # run chef-client to register the node and to bootstrap the instance
## chef-client -j /etc/chef/first-boot.json


####### cleanup log files #######
rm /code/api/shared/log/*
rm /var/log/barbante/*
rm /var/log/barbante_async/*
rm /var/log/apache2/*


####### update application codebase #######
cd /code/api/current
su ubuntu -c '/code/api/.rvm/bin/rvm 2.1.0 do bundle install --binstubs /code/api/shared/bin --path /code/api/shared/bundle --without development test --deployment'
su ubuntu -c './ruby_cron_rvm_bundler.sh peixe "rake api:self_deploy"'

####### stop apache #######
service apache2 stop

####### stop reel (non-async) #######
# supervisorctl stop reel:BarbanteReelServer

# stop kinesis tailer if it was started for any reason
service KinesisTailer stop