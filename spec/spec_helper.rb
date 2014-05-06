Dir['support/**/*.rb'].each { |file| require_relative file }
require_relative '../lib/cloudfoundry_blue_green_deploy'
require 'yaml'

RSpec.configure do |config|
  config.order = 'random'
end
