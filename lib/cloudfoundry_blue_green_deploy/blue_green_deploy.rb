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
    hot_app_name = get_hot_web_app(deploy_config.hot_url)
    both_invalid_and_valid_hot_worker_names = get_hot_worker_names

    if deploy_config.target_color.nil? && hot_app_name
      deploy_config.target_color = determine_target_color(hot_app_name)
    end

    ready_for_takeoff(hot_app_name, both_invalid_and_valid_hot_worker_names, deploy_config)

    cf.push(deploy_config.target_web_app_name)

    deploy_config.target_worker_app_names.each do |worker_app_name|
      cf.push(worker_app_name)
      unless first_deploy?(hot_app_name, both_invalid_and_valid_hot_worker_names)
        to_be_cold_worker = BlueGreenDeployConfig.toggle_app_color(worker_app_name)
        cf.stop(to_be_cold_worker)
      end
    end

    make_hot(app_name, deploy_config)
  end

  def self.ready_for_takeoff(hot_app_name, both_invalid_and_valid_hot_worker_names, deploy_config)
    unless first_deploy?(hot_app_name, both_invalid_and_valid_hot_worker_names)
      ensure_there_is_a_hot_instance(deploy_config, hot_app_name)
      ensure_hot_instance_is_not_target(deploy_config, hot_app_name)
      ensure_hot_workers_are_not_target(deploy_config)
    end
  end

  def self.first_deploy?(hot_app_name, both_invalid_and_valid_hot_worker_names)
     hot_app_name.nil? && both_invalid_and_valid_hot_worker_names.empty?
  end

  def self.ensure_there_is_a_hot_instance(deploy_config, hot_app_name)
    if hot_app_name.nil?
      raise InvalidRouteStateError.new(
        "There is no route mapped from #{deploy_config.hot_url} to an app. " +
        "Indicate which app instance you want to deploy by specifying \"blue\" or \"green\".")
    end
  end

  def self.ensure_hot_instance_is_not_target(deploy_config, hot_app_name)
    if deploy_config.is_in_target?(hot_app_name)
      raise InvalidRouteStateError.new(
        "The app \"#{hot_app_name}\" is already hot (target color is #{deploy_config.target_color}).")
    end
  end

  def self.ensure_hot_workers_are_not_target(deploy_config)
    apps = cf.apps
    deploy_config.target_worker_app_names.each do |hot_worker|
      if deploy_config.is_in_target?(hot_worker) && invalid_worker?(hot_worker, apps)
        raise InvalidWorkerStateError.new(
          "Worker #{hot_worker} is already hot (target color is #{deploy_config.target_color}).")
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
    hot_app = get_hot_web_app(hot_url)
    cold_app = deploy_config.target_web_app_name
    domain = deploy_config.domain

    cf.map_route(cold_app, domain, hot_url)
    cf.unmap_route(hot_app, domain, hot_url) if hot_app
  end

  def self.get_hot_web_app(hot_url)
    cf_routes = cf.routes
    hot_route = cf_routes.find { |route| route.host == hot_url }
    hot_route.nil? ? nil : hot_route.app
  end

  def self.get_hot_worker_names
    cf_apps = cf.apps
    hot_names = []
    cf_apps.each do |app|
      hot_names << app.name if app.state == 'started'
    end
    hot_names
  end
end
