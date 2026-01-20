FactoryBot.define do
  factory :organization, parent: :project, class: 'Organization' do
    # Inherits all attributes from :project factory
    # Can add organization-specific overrides here if needed
  end
end
