class WorkshopSeriesMembership < ApplicationRecord
  belongs_to :workshop_parent, class_name: "Workshop"
  belongs_to :workshop_child, class_name: "Workshop"
end