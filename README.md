# Overview

Using a simple deployment process, one can introduce significant (even if planned) downtime of your application.

If you want to minimize this impact to your site's availability, you might opt to use the Blue/Green deployment approach: http://docs.gopivotal.com/pivotalcf/devguide/deploy-apps/blue-green.html

This gem provides a Rake task to automate Blue/Green deployment to a Cloud Foundry installation.


## Installation

Add this line to your application's Gemfile:

    gem 'cloudfoundry_blue_green_deploy'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install cloudfoundry_blue_green_deploy

## For first deployment - where app to deploy needs to be specified

## Usage

1. define the blue and green instances of your application(s) in your Cloud Foundry Manifest.  (see rules in the next section)
2. run

    $ bundle exec rake cf:blue_green_deploy[web-app-name]

   Where "web-app-name" is the "name" attribute in your manifest.yml.
   The default color for first deployment is blue.
   You may optionally specify the color that you would like to be the "live" instance on the first deployment.

### manifest.yml

Your Cloud Foundry manifest file must comply with the following requirements:

1. name: two application instances are required. One name ending with "-green" and another ending with "-blue"
2. host: the url. One ending with "-green" and the other ending with "-blue"
3. domain: required
4. command: bundle exec rake cf:on_first_instance db:migrate && bundle exec rails s -p $PORT -e $RAILS_ENV
5. services: Optional, only required if there are services that need to be bound

#### Bare Minimum Example:

In this example:
- Our web application is known to Cloud Foundry as "carrot-soup".
- "carrot-soup" has a database service known as "oyster-cracker".

    ---
    applications:

    - name: carrot-soup-green
      host: la-pong-green
      domain: cfapps.io
      command: bundle exec rake cf:on_first_instance db:migrate && bundle exec rails s -p $PORT -e $RAILS_ENV
      services:
      - oyster-cracker

    - name: carrot-soup-blue
      host: la-pong-blue
      domain: cfapps.io
      command: bundle exec rake cf:on_first_instance db:migrate && bundle exec rails s -p $PORT -e $RAILS_ENV
      services:
      - oyster-cracker

And perform a blue/green deploy like this:

    $ bundle exec rake cf:blue_green_deploy[carrot-soup]

## Workers

Non-trivial applications often require background processes to perform asynchronous jobs (e.g. sending email, importing data from external systems, etc.).
If these applications' code are to stay in sync with the web application, they need blue/green treatment as well.

This Rake task natively supports worker application instances.

### Usage (with Workers)

1. define the blue and green instances of your application(s) and workers in your Cloud Foundry Manifest. (see rules in the next section)
2. run:

    $ bundle exec rake cf:blue_green_deploy[web-app-name,worker-name,another-worker-name]

   Note:
     The "web-app-name" is the "name" attribute (without a color) detailed in your manifest.yml
     The "worker-name" and "another-worker-name" are "name" attributes for 2 separate worker apps as detailed in your manifest.yml
     Multiple worker apps can be specified as long as they comply with the blue/green deployment requirements in the manifest.yml

### manifest.yml

For web application deployment (see requirements above)

For worker applications
1. name: two application instances are required. One name ending with "-green" and another ending with "-blue"
2. command:
3. path: Relative to the current working directory
4. services: Optional, only required if there are services that need to be bound

#### Example with Workers

In this example:
- Our web application is known to Cloud Foundry as "carrot-soup".
- The app "carrot-soup" has a database service known as "oyster-cracker".
- We have a worker application named "relish", whose database is known as "creme-fraiche".

    ---
    applications:

    - name: relish-green
      command: bundle exec rails s -p $PORT -e $RAILS_ENV
      path: ../relish
      services:
      - creme-fraiche

    - name: carrot-soup-green
      host: la-pong-green
      domain: cfapps.io
      size: 1GB
      path: .
      command: bundle exec rails s -p $PORT -e $RAILS_ENV
      services:
      - oyster-cracker

    - name: carrot-soup-blue
      host: la-pong-blue
      domain: cfapps.io
      size: 1GB
      path: .
      command: bundle exec rails s -p $PORT -e $RAILS_ENV
      services:
      - oyster-cracker

    - name: relish-blue
      command: bundle exec rails s -p $PORT -e $RAILS_ENV
      path: ../relish
      services:
      - creme-fraiche

 And perform the blue/green deploy like this:
     $ bundle exec rake cf:blue_green_deploy[carrot-soup,relish]


# Blue/Green with Shutter

For blue/green deployments that require a database migration this tool provides the ability to automatically shutter the app during the required downtime. To use this feature, create a shutter app and configure your manifest.yml.

## Creating a Minimal Shutter App

1. Add the following to your manifest.yml. Note that the name must match the name of your production application and end in -shutter.

    - name: carrot-soup-shutter
      command: bundle exec rackup config.ru -p $PORT -E $RACK_ENV
      path: shutter-app

2. Create a directory named "shutter-app".  In that directory:
   1. create a Rack config [config.ru](https://gist.github.com/marianaIAm/4d04a20fdb6d05c64bce)

   2. create a minimal Gemfile:

    source 'https://rubygems.org'
    ruby '2.0.0'

    gem 'rack'

   3. create the Gemfile.lock by running Bundler in the "shutter-app" directory:

    $ bundle install


 - Note: as of 05/09/14 deployment using Cloud Foundry's buildpack does not appear to be compatible with ruby version 2.1.0.
 - Our fail-fast philosophy. We recommend understanding deployment on Cloud Foundry before using this tool.

