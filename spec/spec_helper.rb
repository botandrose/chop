$LOAD_PATH.unshift File.expand_path('../../lib', __FILE__)
require "byebug"
require "capybara"
require "capybara/cuprite"
require "puma"
require "active_record"

# Rails 7.0's adapter pins sqlite3 ~> 1.4, which the gemspec no longer allows.
Kernel.prepend(Module.new { private def gem(name, *) = name == "sqlite3" || super }) if ActiveRecord.version < Gem::Version.new("7.1")

Capybara.server = :puma, { Silent: true }
Capybara.register_driver :cuprite do |app|
  Capybara::Cuprite::Driver.new(app, process_timeout: 20)
end
Capybara.default_driver = :cuprite

RSpec.configure do |config|
  config.filter_run focus: true
  config.run_all_when_everything_filtered = true
end

