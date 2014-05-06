require_relative 'route'
require_relative 'cloud_foundry'
require_relative 'blue_green_deploy_error'
require_relative 'blue_green_deploy_config'

class InvalidRouteStateError < BlueGreenDeployError; end
class InvalidWorkerStateError < BlueGreenDeployError; end

class BlueGreenDeploy
  def self.cf
    CloudFoundry
  end

  def self.make_it_so(app_name, worker_apps, deploy_config)
    hot_app_name = get_hot_app(deploy_config.hot_url)
    if deploy_config.target_color.nil? && hot_app_name
      deploy_config.target_color = determine_target_color(hot_app_name)
    end

    ready_for_takeoff(hot_app_name, deploy_config)

    cf.push(deploy_config.target_web_app_name)
    deploy_config.target_worker_app_names.each do |worker_app_name|
      to_be_cold_worker = BlueGreenDeployConfig.toggle_app_color(worker_app_name)

      cf.push(worker_app_name)
      cf.stop(to_be_cold_worker)
    end
    make_hot(app_name, deploy_config)

  end

  def self.ready_for_takeoff(hot_app_name, deploy_config)
    hot_url = deploy_config.hot_url
    hot_worker_apps = deploy_config.target_worker_app_names
    if hot_app_name.nil?
      raise InvalidRouteStateError.new(
        "There is no route mapped from #{hot_url} to an app. " +
        "Indicate which app instance you want to deploy by specifying \"blue\" or \"green\".")
    end

    if deploy_config.is_in_target?(hot_app_name)
      raise InvalidRouteStateError.new(
        "The #{deploy_config.target_color} instance is already hot.")
    end

    apps = cf.apps
    hot_worker_apps.each do |hot_worker|
      if deploy_config.is_in_target?(hot_worker) && invalid_worker?(hot_worker, apps)
        raise InvalidWorkerStateError.new(
          "Worker #{hot_worker} is already hot (going to #{deploy_config.target_color})")
      end
    end
  end

  def self.invalid_worker?(hot_worker, apps)
    apps.each do |app|
      if app.name == hot_worker && app.state == 'started'
        return true
      end
    end
    return false
  end

  def self.get_color_stem(hot_app_name)
    hot_app_name.slice((hot_app_name.rindex('-') + 1)..(hot_app_name.length))
  end

  def self.determine_target_color(hot_app_name)
    target_color = get_color_stem(hot_app_name)
    BlueGreenDeployConfig.toggle_color(target_color)
  end

  def self.make_hot(app_name, deploy_config)
    hot_url = deploy_config.hot_url
    hot_app = get_hot_app(hot_url)
    cold_app = deploy_config.target_web_app_name
    domain = deploy_config.domain

    cf.map_route(cold_app, domain, hot_url)
    cf.unmap_route(hot_app, domain, hot_url) if hot_app
  end

  def self.get_hot_app(hot_url)
    cf_routes = cf.routes
    hot_route = cf_routes.find { |route| route.host == hot_url }
    hot_route.nil? ? nil : hot_route.app
  end

end
