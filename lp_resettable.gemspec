lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'lp_resettable/version'

Gem::Specification.new do |s|
  s.name        = 'lp_resettable'
  s.version     = LpResettable::VERSION
  s.date        = '2017-02-03'
  s.summary     = 'Password Reset'
  s.description = 'Simple password reset logic'
  s.authors     = ['Ifat Ribon']
  s.email       = 'ifat@launchpadlab.com'
  s.homepage    = 'https://github.com/launchpadlab/lp_resettable'
  s.license     = 'MIT'
  s.files       = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
end
