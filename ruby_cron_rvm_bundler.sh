#! /usr/bin/env bash
 
# Loading the RVM Environment files.
source /code/api/.rvm/environments/default

cd /code/api/current
 
# Call Scout and pass your unique key.
RAILS_ENV=$1 /code/api/.rvm/bin/rvm 2.1.0 do bundle exec $2