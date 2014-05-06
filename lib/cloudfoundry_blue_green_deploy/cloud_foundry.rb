require_relative './command_line'
require_relative './route'
require_relative './app'

class CloudFoundryCliError < StandardError; end

class CloudFoundry

  def self.apps
    apps = []
    cmd = "cf apps"
    output = CommandLine.backtick(cmd)
    found_header = false

    lines = output.lines

    lines.each do |line|
      line = line.split
      if line[0] == 'name' && found_header == false
        found_header = true
        next
      end

      if found_header
        apps << App.new(name: line[0], state: line[1])
      end
    end

    apps
  end

  def self.push(app)
    execute("cf push #{app}")
  end

  def self.stop(app)
    execute("cf stop #{app}")
  end

  def self.routes
    routes = []
    cmd = "cf routes"
    output = CommandLine.backtick(cmd)
    success = !output.include?('FAILED')
    if success
      lines = output.lines
      found_header = false
      lines.each do |line|
        line = line.split
        if line[0] == 'host' && found_header == false
          found_header = true
          next
        end

        if found_header
          routes << Route.new(line[0], line[1], line[2])
        end
      end
      routes
    else
      raise CloudFoundryCliError.new("\"#{cmd}\" returned \"#{success}\".  The output of the command was \n\"#{output}\".")
    end
  end

  def self.unmap_route(app, domain, host)
    execute("cf unmap-route #{app} #{domain} -n #{host}")
  end

  def self.map_route(app, domain, host)
    execute("cf map-route #{app} #{domain} -n #{host}")
  end

  private

  def self.execute(cmd)
    success = CommandLine.system(cmd)
    handle_success_or_failure(cmd, success)
  end

  def self.handle_success_or_failure(cmd, success)
    if success
      return success
    else
      raise CloudFoundryCliError.new("\"#{cmd}\" returned \"#{success}\".  Look for details in \"FAILED\" above.")
    end
  end
end
