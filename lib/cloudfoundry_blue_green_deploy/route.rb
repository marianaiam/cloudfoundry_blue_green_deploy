module CloudfoundryBlueGreenDeploy
  class Route
    attr_reader :host, :domain, :app
    def initialize(host, domain, app)
      @host = host
      @domain = domain
      @app = app == '' ? nil : app
    end
  end
end
