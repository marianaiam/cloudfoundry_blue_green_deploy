require 'rails'

module CloudFoundryBlueGreenDeploy
  class Railtie < Rails::Railtie
    railtie_name :cloudfoundry_blue_green_deploy

    rake_tasks do
      load 'tasks/cf.rake'
    end
  end
end
