require_relative 'blue_green_deploy_error'

module CloudfoundryBlueGreenDeploy
  class InvalidManifestError < BlueGreenDeployError; end

  class BlueGreenDeployConfig
    attr_reader :hot_url, :worker_app_names, :domain, :with_shutter
    attr_accessor :target_color

    def initialize(cf_manifest, web_app_name, worker_app_names, with_shutter = nil)
      manifest = cf_manifest['applications']

      self.class.valid_name_check(web_app_name, worker_app_names, manifest)

      item = manifest.find { |item| self.class.strip_color(item['name']) == web_app_name }
      if item.nil?
        raise InvalidManifestError.new("Could not find \"#{web_app_name}-green\" nor \"#{web_app_name}-blue\" in the Cloud Foundry manifest:\n" +
                                       "#{cf_manifest.inspect}")
      end

      host = item['host']
      if host.nil?
        raise InvalidManifestError.new(
          "Could not find the \"host\" property associated with the \"#{item['name']}\" application in the Cloud Foundry manifest:\n" +
          "#{cf_manifest.inspect}")
      end

      @domain = item['domain']

      if @domain.nil?
        raise InvalidManifestError.new(
          "Could not find the \"domain\" property associated with the \"#{item['name']}\" application in the Cloud Foundry manifest:\n" +
          "#{cf_manifest.inspect}")
      end

      @web_app_name = web_app_name
      @hot_url = host.slice(0, host.rindex('-'))
      @worker_app_names = worker_app_names
      @with_shutter = with_shutter
      @target_color = nil
    end

    def shutter_app_name
      "#{@web_app_name}-shutter"
    end

    def target_web_app_name
      "#{@web_app_name}-#{@target_color}"
    end

    def is_in_target?(app)
      self.class.get_color_stem(app) == @target_color
    end

    def target_worker_app_names
      @worker_app_names.map do |app|
        "#{app}-#{@target_color}"
      end
    end


    def self.valid_name_check(web_app_name, worker_app_names, manifest)
      all_apps = all_app_names(web_app_name, worker_app_names)
      all_apps.each do |app_name|
        if manifest.none? { |record| record['name'] == app_name }
          raise InvalidManifestError.new("Could not find \"#{app_name}\" in the Cloud Foundry manifest:\n" +
                                         "#{manifest}")

        end
      end
    end

    def self.strip_color(app_name_with_color)
      app_name_with_color.slice((0..app_name_with_color.rindex('-') - 1))
    end

    def self.toggle_app_color(target_app_name)
      new_color = toggle_color(get_color_stem(target_app_name))
      new_app = target_app_name.slice(0..(target_app_name.rindex('-') - 1))
      new_app = "#{new_app}-#{new_color}"
    end

    def self.get_color_stem(app_name)
      app_name.slice((app_name.rindex('-') + 1)..(app_name.length))
    end

    def self.toggle_color(target_color)
      target_color == 'green' ? 'blue' : 'green'
    end

    def self.colorize_name(app_name, color)
      "#{app_name}-#{color}"
    end

    def self.all_app_names(web_app_name, worker_app_names)
      all_app_names = []
      all_app_names <<  colorize_name(web_app_name, 'blue')
      all_app_names <<  colorize_name(web_app_name, 'green')

      worker_app_names.each do |app|
        all_app_names << colorize_name(app, 'green')
        all_app_names << colorize_name(app, 'blue')
      end

      all_app_names
    end
  end
end
