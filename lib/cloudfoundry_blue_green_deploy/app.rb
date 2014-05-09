module CloudfoundryBlueGreenDeploy
  class App
    attr_accessor :name, :state

    def initialize(name: , state: 'stopped')
      @name = name
      @state = state
    end
  end
end
