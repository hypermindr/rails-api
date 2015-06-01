# Barbante's Recommendation API #

This Rails API implements Barbante's recommendation engine do provide a recommendation service to one or more sites. Although it is not required to use this API to use Barbante, it does come loaded with RESTful API endpoints, a javascript library for client-side implementation, and a dashboard for quick access to system statistics. 

### Requirements ###

* Ruby version 2.1.0
* Rails version 4.0.2
* MongoDB 2.6.9 or later
* Redis
* Memcached
* [Barbante](https://github.com/hypermindr/barbante)
* Web server (Apache or nginx)
* Application server (Passenger, Unicorn or Puma)


### Configuration ###
It is possible to run the recommendation system in one standalone server, but we recommend distributing the services throughout a cluster for high volume production environments. 

Installation should be straightforward. Install all requirements and configure apache to host your rails installation. We use [capistrano](http://capistranorb.com/) for application deploys, so once you are all set to deploy you application, take a look at the capistrano deploy environments and make necessary adjustments to tailor it to your environments.

Before deploying, make sure you configure access to the database servers and redis servers, setting those to localhost if you are using a standalone configuration. MongoDB configuration is on config/mongoid.yml and redis on config/settings/environment.yml. If you are hosted on AWS EC2, add your access keys on config/ec2.yml and config/settings.yml.

Once you are able to deploy the application to your server, open your browser and point to your hostname. If everything is right, then you should get a login page. You need to create a login by runing the database seeds script. First edit db/seeds.rb with the credentials of your choice, then run rake db:seed on your server and you should then be able to login. Authentication for the dashboard is done with [Devise](https://github.com/plataformatec/devise).


### Who do I talk to? ###

* [Gastão Brun](mailto:gastaobrun@gmail.com)
