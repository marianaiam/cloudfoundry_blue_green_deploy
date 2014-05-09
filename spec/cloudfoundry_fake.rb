module CloudfoundryBlueGreenDeploy
  class CloudfoundryFake
    def self.init_route_table(domain, web_app_name, hot_url, current_hot_color)
      @@web_app_name = web_app_name
      @@current_hot_color = current_hot_color
      @@hot_url = hot_url
      @@cf_route_table = [
        Route.new("#{web_app_name}-blue", domain, "#{web_app_name}-blue"),
        Route.new("#{web_app_name}-green", domain, "#{web_app_name}-green"),
        Route.new(hot_url, domain, "#{web_app_name}-#{current_hot_color}")
      ]
    end

    def self.clear_route_table
      @@cf_route_table = []
    end

    def self.init_app_list_with_workers_for(app_name)
      @@cf_app_list = [
        App.new(name: "#{app_name}-worker-green", state: 'stopped'),
        App.new(name: "#{app_name}-worker-blue", state: 'stopped')
      ]
    end

    def self.init_app_list_from_names(app_names)
      @@cf_app_list = []
      app_names.each do |app|
        ['blue', 'green'].each do |color|
          @@cf_app_list << App.new(name: "#{app}-#{color}", state: 'stopped')
        end
      end
    end

    def self.mark_app_as_started(full_worker_app_name)
      @@cf_app_list.find { |app| app.name == full_worker_app_name }.state = 'started'
    end

    def self.mark_workers_as_started(worker_app_names, target_color)
      @@cf_app_list.each do |app|
        worker_app_names.each do |worker_name|
          if app.name == "#{worker_name}-#{target_color}"
            app.state = 'started'
          end
        end
      end
    end

    def self.init_app_list(apps)
      @@cf_app_list = apps
    end

    def self.clear_app_list
      @@cf_app_list = []
    end

    # App List Helpers

    def self.replace_app(new_app)
      app_index = @@cf_app_list.find_index { |existing_app| existing_app.name == new_app.name }
      @@cf_app_list[app_index] = new_app
    end

    def self.apps
      @@cf_app_list
    end


    def self.started_apps
      @@cf_app_list.select { |app| app.state == 'started' }
    end

    # Route Table Helpers
    def self.find_route(host)
      @@cf_route_table.find { |route| route.host == host }
    end

    def self.add_route(route)
      @@cf_route_table << route
    end

    def self.remove_route(host)
      @@cf_route_table.delete_if { |route| route.host == host }
    end

    # Cloudfoundry fakes
    def self.push(app)
    end

    def self.stop(app)
    end

    def self.routes
      @@cf_route_table
    end

    def self.unmap_route(app, domain, host)
      @@cf_route_table.delete_if { |route| route.app == "#{@@web_app_name}-#{@@current_hot_color}" && route.host == @@hot_url }
    end

    def self.map_route(app, domain, host)
      @@cf_route_table.delete_if { |route| route.host == host }
      @@cf_route_table.push(Route.new(host, domain, app))
    end
  end
end
