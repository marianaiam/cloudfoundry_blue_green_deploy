require 'rails'

module CloudfoundryBlueGreenDeploy
  class Railtie < Rails::Railtie
    railtie_name :cloudfoundry_blue_green_deploy

    rake_tasks do
      load 'cloudfoundry_blue_green_deploy/tasks/cf.rake'
    end
  end
end
