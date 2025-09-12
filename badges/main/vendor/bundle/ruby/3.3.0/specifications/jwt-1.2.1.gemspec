# -*- encoding: utf-8 -*-
# stub: jwt 1.2.1 ruby lib

Gem::Specification.new do |s|
  s.name = "jwt".freeze
  s.version = "1.2.1".freeze

  s.required_rubygems_version = Gem::Requirement.new(">= 1.2".freeze) if s.respond_to? :required_rubygems_version=
  s.require_paths = ["lib".freeze]
  s.authors = ["Jeff Lindsay".freeze]
  s.date = "2015-01-23"
  s.description = "JSON Web Token implementation in Ruby".freeze
  s.email = "progrium@gmail.com".freeze
  s.extra_rdoc_files = ["lib/jwt.rb".freeze, "lib/jwt/json.rb".freeze]
  s.files = ["lib/jwt.rb".freeze, "lib/jwt/json.rb".freeze]
  s.homepage = "http://github.com/progrium/ruby-jwt".freeze
  s.licenses = ["MIT".freeze]
  s.rdoc_options = ["--line-numbers".freeze, "--title".freeze, "Jwt".freeze, "--main".freeze, "README.md".freeze]
  s.rubygems_version = "2.3.0".freeze
  s.summary = "JSON Web Token implementation in Ruby".freeze

  s.installed_by_version = "3.5.22".freeze

  s.specification_version = 4

  s.add_development_dependency(%q<echoe>.freeze, [">= 4.6.3".freeze])
end
