# -*- encoding: utf-8 -*-
# stub: activerecord-trilogy-adapter 3.2.0 ruby lib

Gem::Specification.new do |s|
  s.name = "activerecord-trilogy-adapter".freeze
  s.version = "3.2.0".freeze

  s.required_rubygems_version = Gem::Requirement.new(">= 0".freeze) if s.respond_to? :required_rubygems_version=
  s.metadata = { "bug_tracker_uri" => "https://github.com/trilogy-libraries/activerecord-trilogy-adapter/issues", "changelog_uri" => "https://github.com/trilogy-libraries/activerecord-trilogy-adapter/blob/master/CHANGELOG.md", "source_code_uri" => "https://github.com/trilogy-libraries/activerecord-trilogy-adapter" } if s.respond_to? :metadata=
  s.require_paths = ["lib".freeze]
  s.authors = ["GitHub Engineering".freeze]
  s.date = "2025-05-21"
  s.description = "This gem is only needed before Rails 7.1, where the trilogy adapter is built in. \nWhen you upgrade to a version after 7.1.a, replace this with `gem \"trilogy\"` to ensure\nthat trilogy itself is available.\n".freeze
  s.email = ["opensource+trilogy@github.com".freeze]
  s.extra_rdoc_files = ["README.md".freeze, "LICENSE.md".freeze]
  s.files = ["LICENSE.md".freeze, "README.md".freeze]
  s.homepage = "https://github.com/trilogy-libraries/activerecord-trilogy-adapter".freeze
  s.licenses = ["MIT".freeze]
  s.rubygems_version = "3.2.33".freeze
  s.summary = "Active Record adapter for https://github.com/trilogy-libraries/trilogy.".freeze

  s.installed_by_version = "3.5.22".freeze

  s.specification_version = 4

  s.add_runtime_dependency(%q<trilogy>.freeze, [">= 2.4.0".freeze])
  s.add_runtime_dependency(%q<activerecord>.freeze, [">= 6.0.a".freeze, "< 7.1.a".freeze])
  s.add_development_dependency(%q<minitest>.freeze, ["~> 5.11".freeze])
  s.add_development_dependency(%q<minitest-focus>.freeze, ["~> 1.1".freeze])
  s.add_development_dependency(%q<pry>.freeze, ["~> 0.10".freeze])
  s.add_development_dependency(%q<rake>.freeze, ["~> 12.3".freeze])
end
