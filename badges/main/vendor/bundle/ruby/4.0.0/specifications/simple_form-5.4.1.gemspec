# -*- encoding: utf-8 -*-
# stub: simple_form 5.4.1 ruby lib

Gem::Specification.new do |s|
  s.name = "simple_form".freeze
  s.version = "5.4.1".freeze

  s.required_rubygems_version = Gem::Requirement.new(">= 0".freeze) if s.respond_to? :required_rubygems_version=
  s.metadata = { "bug_tracker_uri" => "https://github.com/heartcombo/simple_form/issues", "changelog_uri" => "https://github.com/heartcombo/simple_form/blob/main/CHANGELOG.md", "documentation_uri" => "https://rubydoc.info/github/heartcombo/simple_form", "homepage_uri" => "https://github.com/heartcombo/simple_form", "source_code_uri" => "https://github.com/heartcombo/simple_form", "wiki_uri" => "https://github.com/heartcombo/simple_form/wiki" } if s.respond_to? :metadata=
  s.require_paths = ["lib".freeze]
  s.authors = ["Jos\u00E9 Valim".freeze, "Carlos Antonio".freeze, "Rafael Fran\u00E7a".freeze]
  s.date = "1980-01-02"
  s.description = "Forms made easy!".freeze
  s.email = "heartcombo.oss@gmail.com".freeze
  s.homepage = "https://github.com/heartcombo/simple_form".freeze
  s.licenses = ["MIT".freeze]
  s.required_ruby_version = Gem::Requirement.new(">= 2.7.0".freeze)
  s.rubygems_version = "4.0.3".freeze
  s.summary = "Forms made easy!".freeze

  s.installed_by_version = "4.0.3".freeze

  s.specification_version = 4

  s.add_runtime_dependency(%q<activemodel>.freeze, [">= 7.0".freeze])
  s.add_runtime_dependency(%q<actionpack>.freeze, [">= 7.0".freeze])
  s.add_development_dependency(%q<country_select>.freeze, [">= 0".freeze])
  s.add_development_dependency(%q<minitest>.freeze, ["< 6".freeze])
  s.add_development_dependency(%q<rake>.freeze, [">= 0".freeze])
  s.add_development_dependency(%q<rdoc>.freeze, [">= 0".freeze])
end
