class ProjectObligation < ApplicationRecord
  OBLIGATION_TYPES = ['Current Grant Funded', 'Previous Grant Funded',
                      'Voluntary Reporting', 'Intermittent Reporting',
                      'Active Non-Reporting']

  def self.create_defaults
    OBLIGATION_TYPES.each do |name|
      ProjectObligation.find_or_create_by(name: name)
     end
  end
end
