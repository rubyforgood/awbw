class ProjectObligation < ApplicationRecord
  OBLIGATION_TYPES = ['Current Grant Funded', 'Previous Grant Funded',
                      'Voluntary Reporting', 'Intermittent Reporting',
                      'Active Non-Reporting']
end
