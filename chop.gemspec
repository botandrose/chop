# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'chop/version'

Gem::Specification.new do |spec|
  spec.name          = "chop"
  spec.version       = Chop::VERSION
  spec.authors       = ["Micah Geisel"]
  spec.email         = ["micah@botandrose.com"]

  spec.summary       = %q{Slice and dice your cucumber tables with ease!}
  spec.description   = %q{Slice and dice your cucumber tables with ease!}
  spec.homepage      = "http://github.com/botandrose/chop"
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency "activerecord"
  spec.add_dependency "cucumber"
  spec.add_dependency "capybara"

  spec.add_development_dependency "appraisal"
  spec.add_development_dependency "rake"
  spec.add_development_dependency "rspec"
  spec.add_development_dependency "slim"
  spec.add_development_dependency "cuprite"
end
