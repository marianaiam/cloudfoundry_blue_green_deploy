# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'cloudfoundry_blue_green_deploy/version'

Gem::Specification.new do |spec|
  spec.name          = 'cloudfoundry_blue_green_deploy'
  spec.version       = CloudfoundryBlueGreenDeploy::VERSION
  spec.authors       = ['John Ryan and Mariana Lenetis']
  spec.email         = ['jryan@pivotal.io', 'mlenetis@pivotal.io']
  spec.summary       = %q{Blue-green deployment tool for Cloud Foundry.}
  spec.description   = %q{Blue-green deployment tool for Cloud Foundry. Please see readme.}
  spec.homepage      = 'https://github.com/marianaIAm/cloudfoundry_blue_green_deploy'
  spec.license       = 'MIT'

  spec.files         = `git ls-files -z`.split("\x0")
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ['lib']
  spec.required_ruby_version = '~> 2.1'

  spec.add_development_dependency 'bundler', '~> 1.6'
  spec.add_development_dependency 'rake'
  spec.add_development_dependency 'rspec'
  spec.add_development_dependency 'awesome_print'
end
