$LOAD_PATH.unshift File.expand_path('../../lib', __FILE__)
require "byebug"

RSpec.configure do |c|
  c.filter_run_when_matching :focus
end
