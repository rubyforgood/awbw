# -*- encoding: utf-8 -*-
# stub: css_parser 1.17.1 ruby lib

Gem::Specification.new do |s|
  s.name = "css_parser".freeze
  s.version = "1.17.1".freeze

  s.required_rubygems_version = Gem::Requirement.new(">= 0".freeze) if s.respond_to? :required_rubygems_version=
  s.metadata = { "bug_tracker_uri" => "https://github.com/premailer/css_parser/issues", "changelog_uri" => "https://github.com/premailer/css_parser/blob/master/CHANGELOG.md", "rubygems_mfa_required" => "true", "source_code_uri" => "https://github.com/premailer/css_parser" } if s.respond_to? :metadata=
  s.require_paths = ["lib".freeze]
  s.authors = ["Alex Dunae".freeze]
  s.date = "2024-04-07"
  s.description = "A set of classes for parsing CSS in Ruby.".freeze
  s.email = "code@dunae.ca".freeze
  s.homepage = "https://github.com/premailer/css_parser".freeze
  s.licenses = ["MIT".freeze]
  s.required_ruby_version = Gem::Requirement.new(">= 2.7".freeze)
  s.rubygems_version = "3.1.6".freeze
  s.summary = "Ruby CSS parser.".freeze

  s.installed_by_version = "3.5.22".freeze

  s.specification_version = 4

  s.add_runtime_dependency(%q<addressable>.freeze, [">= 0".freeze])
  s.add_development_dependency(%q<benchmark-ips>.freeze, [">= 0".freeze])
  s.add_development_dependency(%q<bump>.freeze, [">= 0".freeze])
  s.add_development_dependency(%q<maxitest>.freeze, [">= 0".freeze])
  s.add_development_dependency(%q<memory_profiler>.freeze, [">= 0".freeze])
  s.add_development_dependency(%q<rake>.freeze, [">= 0".freeze])
  s.add_development_dependency(%q<rubocop>.freeze, ["~> 1.8".freeze])
  s.add_development_dependency(%q<rubocop-rake>.freeze, [">= 0".freeze])
  s.add_development_dependency(%q<webrick>.freeze, [">= 0".freeze])
end
