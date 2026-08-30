class OrganizationObligation < ApplicationRecord
  belongs_to :created_by, class_name: "User", optional: true
  belongs_to :updated_by, class_name: "User", optional: true

  OBLIGATION_TYPES = [ "Current Grant Funded", "Previous Grant Funded",
                      "Voluntary Reporting", "Intermittent Reporting",
                      "Active Non-Reporting" ]
end
