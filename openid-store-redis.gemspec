# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'openid/store/redis/version'

Gem::Specification.new do |spec|
  spec.name          = "openid-store-redis"
  spec.version       = OpenID::Store::REDIS_VERSION
  spec.authors       = ["Ville Lautanala"]
  spec.email         = ["lautis@gmail.com"]
  spec.description   = %q{Use Redis to store OpenID associations and nonces with ruby-openid}
  spec.summary       = %q{A Redis storage backend for ruby-openid}
  spec.homepage      = ""
  spec.license       = "MIT"

  spec.files         = `git ls-files`.split($/)
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.required_ruby_version = '>= 1.9.3'

  spec.add_runtime_dependency "ruby-openid", ">= 2.1.7"
  spec.add_runtime_dependency "redis", ">= 3.0", "< 5.0"

  spec.add_development_dependency "bundler", "~> 1.3"
  spec.add_development_dependency "rake"
  spec.add_development_dependency "rspec", "~> 3.0"
  spec.add_development_dependency "mock_redis"
end
