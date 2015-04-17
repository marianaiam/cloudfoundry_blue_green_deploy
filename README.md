# Overview

Using a simple deployment process, downtime can occur. By running two identical production environments (Blue and Green), the risk of significant downtime is minimized. If you want to automate this process and minimize errors, use the Blue/Green deployment approach: http://docs.gopivotal.com/pivotalcf/devguide/deploy-apps/blue-green.html

This gem provides a Rake task to automate Blue/Green deployment to a Cloud Foundry installation. For deployments that include migrations, there is an option to deploy a Rack-based shutter app.


## Installation

Currently, this gem requires Ruby 2.1.x or better. It is compatible with [Cloud Foundy CLI](https://github.com/cloudfoundry/cli) versions 6.6 - 6.11.

Add this line to your application's Gemfile:

    gem 'cloudfoundry_blue_green_deploy'

And then execute:

    $ bundle install

Or download and install:

    $ gem install cloudfoundry_blue_green_deploy

## First Deployment
Make sure that all services that are specified in the manifest.yml file are created before running a first deployment.

## Usage

1. Define the Blue and Green instances of your application(s) in your Cloud Foundry Manifest.  (see rules in the next section)

2. Run:

        $ bundle exec rake cf:blue_green_deploy[web-app-name]

   Where "web-app-name" is the "name" attribute in your manifest.yml.
   The default color for first deployment is blue.

### manifest.yml

Your Cloud Foundry manifest file must comply with the following requirements:

- `name`: two application instances are required. One name ending with `-green` and another ending with `-blue`
- `host`: the url. One ending with `-green` and the other ending with `-blue`
- `domain`: required
- `memory`: optional, default will be used if omitted
- `command`: `bundle exec rake cf:on_first_instance db:migrate && bundle exec rails s -p $PORT -e $RAILS_ENV`
- `services`: Optional, only required if there are services that need to be bound

#### Bare Minimum Example:

In this example:
Our web application is known to Cloud Foundry as `awesome-app` with a database service known as `memory-bank-db`. Its URL is `awesomeapp.cfapps.io`.

    ---
    applications:
    - name: awesome-app-blue
      host: awesomeapp-blue
      domain: cfapps.io
      command: bundle exec rake cf:on_first_instance db:migrate && bundle exec rails s -p $PORT -e $RAILS_ENV
      services:
      - memory-bank-db

    - name: awesome-app-green
      host: awesomeapp-green
      domain: cfapps.io
      command: bundle exec rake cf:on_first_instance db:migrate && bundle exec rails s -p $PORT -e $RAILS_ENV
      services:
      - memory-bank-db

And perform a blue/green deploy like this:

    $ bundle exec rake cf:blue_green_deploy[awesome-app]

## Workers

Non-trivial applications often require background processes to perform asynchronous jobs (e.g. sending email, importing data from external systems, etc.).
If these applications' code are to stay in sync with the web application, they need Blue and Green treatment as well.

This Rake task natively supports worker application instances.

### Usage (with Workers)

1. Define the Blue and Green instances of your application and workers in your Cloud Foundry Manifest. (see rules in the next section)
2. Run:


        $ bundle exec rake cf:blue_green_deploy[web-app-name,worker-name,another-worker-name]


- The `web-app-name` is the `name` attribute (without a color) detailed in your manifest.yml
- The `worker-name` and `another-worker-name` are `name` attributes for two separate worker apps as detailed in your manifest.yml
- Multiple worker apps can be specified as long as they comply with the blue/green deployment requirements in the manifest.yml.

### manifest.yml

For web application deployment (see requirements above)

For worker applications:
- `name`: Two application instances are required. One name ending with `-green` and another ending with `-blue`
- `command`: Required
- `path`: Relative to the current working directory
- `services`: Optional, only required if there are services that need to be bound

#### Example with Workers

In this example:
- Our web application is known to Cloud Foundry as `awesome-app`.
- Its URL is `awesomeapp.cfapps.io`
- The app `awesome-app` has a database service known as `memory-bank-db`.
- We have a worker application named `super-queue`, whose database is known as `key-vals-db`.

        ---
        applications:
        - name: awesome-app-blue
          host: awesomeapp-blue
          domain: cfapps.io
          memory: 1GB
          path: .
          command: bundle exec rails s -p $PORT -e $RAILS_ENV
          services:
          - memory-bank-db

        - name: awesome-app-green
          host: awesomeapp-green
          domain: cfapps.io
          memory: 1GB
          path: .
          command: bundle exec rails s -p $PORT -e $RAILS_ENV
          services:
          - memory-bank-db

        - name: super-queue-blue
          command: bundle exec rails s -p $PORT -e $RAILS_ENV
          path: ../super-queue
          services:
          - key-vals-db

        - name: super-queue-green
          command: bundle exec rails s -p $PORT -e $RAILS_ENV
          path: ../super-queue
          services:
          - key-vals-db


And perform the blue/green deploy like this:

    $ bundle exec rake cf:blue_green_deploy[awesome-app, super-queue]

# Blue/Green with Shutter

For Blue and Green deployments that require a database migration this tool provides the ability to automatically shutter the app during the required downtime. To use this feature, create a shutter app and configure your `manifest.yml`.

## Creating a Minimal Shutter App

1. Add the following to your manifest.yml. Note that the name must match the name of your production application and end in -shutter.

        - name: awesome-app-shutter
          command: bundle exec rackup config.ru -p $PORT -E $RACK_ENV
          path: shutter-app

2. Create a directory named `shutter-app`. In that directory:

- Create a Rack config [config.ru](https://gist.github.com/marianaIAm/4d04a20fdb6d05c64bce)

- Create a minimal Gemfile:

        source 'https://rubygems.org'
        ruby '2.1.2'

        gem 'rack'

- Create the Gemfile.lock by running Bundler in the `shutter-app` directory:

        $ bundle install


Our fail-fast philosophy. We recommend understanding deployment on Cloud Foundry before using this tool.
