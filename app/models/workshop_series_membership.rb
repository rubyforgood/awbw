class WorkshopSeriesMembership < ApplicationRecord
  belongs_to :workshop_parent, class_name: "Workshop"
  belongs_to :workshop_child, class_name: "Workshop"

  validates :series_order, presence: true, numericality: { only_integer: true, greater_than: 0 }
end