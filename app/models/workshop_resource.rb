class WorkshopResource < ApplicationRecord
  belongs_to :workshop
  belongs_to :resource
  belongs_to :created_by, class_name: "User", optional: true
  belongs_to :updated_by, class_name: "User", optional: true
end
