$LOAD_PATH.unshift File.expand_path('../../lib', __FILE__)
require "byebug"
require "capybara"
require "capybara/cuprite"
require "puma"

Capybara.server = :puma, { Silent: true }
Capybara.register_driver :cuprite do |app|
  Capybara::Cuprite::Driver.new(app, process_timeout: 20)
end
Capybara.default_driver = :cuprite

RSpec.configure do |config|
  config.filter_run focus: true
  config.run_all_when_everything_filtered = true
end

