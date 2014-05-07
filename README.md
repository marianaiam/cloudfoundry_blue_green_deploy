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

    $ bundle exec rake cf:blue_green_deploy[web-app-name,blue]

   where "web-app-name" is the "name" attribute (with a color) in your manifest.yml.
   specify the color that you would like to be the "live" instance on the first deployment.

### manifest.yml

Your Cloud Foundry manifest file must comply with the following requirements:

1. name: two application instances are required. One name ending with "-green" and another ending with "-blue"
2. host: the url. One ending with "-green" and the other ending with "-blue"
3. domain: required
4. command: Must not include a migration
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
      command: bundle exec rails s -p $PORT -e $RAILS_ENV
      services:
      - oyster-cracker

    - name: carrot-soup-blue
      host: la-pong-blue
      domain: cfapps.io
      command: bundle exec rails s -p $PORT -e $RAILS_ENV
      services:
      - oyster-cracker

And perform a blue/green deploy like this:

    $ bundle exec rake cf:blue_green_deploy[carrot-soup]

## Usage

1. define the blue and green instances of your application(s) in your Cloud Foundry Manifest.  (see rules in the next section)
2. run

    $ bundle exec rake cf:blue_green_deploy[web-app-name]

   where "web-app-name" is the "name" attribute (without a color) in your manifest.yml.

### manifest.yml

Your Cloud Foundry manifest file must comply with the following requirements:

1. name: two application instances are required. One name ending with "-green" and another ending with "-blue"
2. host: the url. One ending with "-green" and the other ending with "-blue"
3. domain: required
4. command: Must not include a migration
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
      command: bundle exec rails s -p $PORT -e $RAILS_ENV
      services:
      - oyster-cracker

    - name: carrot-soup-blue
      host: la-pong-blue
      domain: cfapps.io
      command: bundle exec rails s -p $PORT -e $RAILS_ENV
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
     "web-app-name" is the "name" attribute (without a color) is detailed in your manifest.yml
     "worker-name" and "another-worker-name" are "name" attributes for 2 separate worker apps as detailed in your manifest.yml
     Multiple worker apps can be specified as long as they comply with the blue/green deployment requirements in the manifest.yml

### manifest.yml

For web application deployment (see requirements above)

For worker applications
1. name: two application instances are required. One name ending with "-green" and another ending with "-blue"
2. command: Must not include a migration
3. path: Relative to the current working directory
4. services: Optional, only required if there are services that need to be bound

#### Example with Workers

In this example:
- Our web application is known to Cloud Foundry as "carrot-soup".
- "carrot-soup" has a database service known as "oyster-cracker".
- We have a worker application named "pickle-breath".
- It's database is known as "creme-fraiche".

    ---
    applications:

    - name: pickle-breath-green
      command: bundle exec rails s -p $PORT -e $RAILS_ENV
      path: ../pickle_breath
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

    - name: pickle-breath-blue
      command: bundle exec rails s -p $PORT -e $RAILS_ENV
      path: ../pickle_breath
      services:
      - creme-fraiche

 And perform the blue/green deploy like this:
     $ bundle exec rake cf:blue_green_deploy[carrot-soup,pickle-breath]



 Stuff to add:
 - Our fail-fast philosophy. We recommend understanding deployment on Cloud Foundry before using this tool.

