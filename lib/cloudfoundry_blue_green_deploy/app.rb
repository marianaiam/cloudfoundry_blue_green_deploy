class App
  attr_reader :name, :state

  def initialize(name: , state: 'stopped')
    @name = name
    @state = state
  end
end
