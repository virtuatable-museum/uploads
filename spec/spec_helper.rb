require 'simplecov'
SimpleCov.start

ENV['RACK_ENV'] = 'test'

require 'bundler'
Bundler.require :test

Aws.config.update({
  credentials: Aws::Credentials.new(
    ENV['AWS_ACCESS_KEY_ID'],
    ENV['AWS_SECRET_ACCESS_KEY']
  ),
  region: ENV['AWS_REGION'],
  endpoint: ENV['AWS_ENDPOINT']
})

require './services/module.rb'

Dotenv.load(File.join(File.dirname(__FILE__), '..', '.env'))

require 'arkaan/specs'

service = Arkaan::Utils::MicroService.instance
  .register_as('uploads')
  .from_location(__FILE__)
  .in_test_mode

Arkaan::Specs.include_shared_examples