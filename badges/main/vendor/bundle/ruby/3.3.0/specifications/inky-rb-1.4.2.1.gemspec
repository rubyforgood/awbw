# -*- encoding: utf-8 -*-
# stub: inky-rb 1.4.2.1 ruby lib

Gem::Specification.new do |s|
  s.name = "inky-rb".freeze
  s.version = "1.4.2.1".freeze

  s.required_rubygems_version = Gem::Requirement.new(">= 0".freeze) if s.respond_to? :required_rubygems_version=
  s.require_paths = ["lib".freeze]
  s.authors = ["Foundation".freeze]
  s.date = "2023-10-16"
  s.description = "Inky is an HTML-based templating language that converts simple HTML into complex, responsive email-ready HTML. Designed for Foundation for Emails".freeze
  s.email = ["contact@get.foundation".freeze]
  s.homepage = "https://github.com/foundation/inky-rb".freeze
  s.licenses = ["MIT".freeze]
  s.rubygems_version = "3.4.10".freeze
  s.summary = "Inky is an HTML-based templating language that converts simple HTML into complex, responsive email-ready HTML. Designed for Foundation for Emails".freeze

  s.installed_by_version = "3.5.22".freeze

  s.specification_version = 4

  s.add_runtime_dependency(%q<foundation_emails>.freeze, ["~> 2".freeze])
  s.add_runtime_dependency(%q<nokogiri>.freeze, [">= 0".freeze])
  s.add_development_dependency(%q<bundler>.freeze, [">= 0".freeze])
  s.add_development_dependency(%q<capybara>.freeze, [">= 0".freeze])
  s.add_development_dependency(%q<rails>.freeze, [">= 0".freeze])
  s.add_development_dependency(%q<rake>.freeze, [">= 0".freeze])
  s.add_development_dependency(%q<rspec-rails>.freeze, [">= 0".freeze])
  s.add_development_dependency(%q<rubocop>.freeze, [">= 0".freeze])
  s.add_development_dependency(%q<slim>.freeze, [">= 0".freeze])
end
