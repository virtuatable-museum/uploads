require 'bundler'
Bundler.require(ENV['RACK_ENV'].to_sym || :development)

Aws.config.update({
  credentials: Aws::Credentials.new(
    ENV['AWS_ACCESS_KEY_ID'],
    ENV['AWS_SECRET_ACCESS_KEY']
  ),
  region: ENV['AWS_REGION'],
  endpoint: ENV['AWS_ENDPOINT']
})

require 'services/module'
require 'controllers/base'

$stdout.sync = true

service = Arkaan::Utils::MicroService.instance
  .register_as('uploads')
  .from_location(__FILE__)
  .in_standard_mode

run Controllers::Characters

at_exit { Arkaan::Utils::MicroService.instance.deactivate! }