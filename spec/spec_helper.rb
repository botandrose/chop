$LOAD_PATH.unshift File.expand_path('../../lib', __FILE__)
require "byebug"

RSpec.configure do |config|
  config.filter_run focus: true
  config.run_all_when_everything_filtered = true
end

def ruby_2_7_or_greater?
  RUBY_VERSION >= "2.7.0"
end
