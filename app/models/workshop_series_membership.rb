class WorkshopSeriesMembership < ApplicationRecord
  belongs_to :workshop_parent, class_name: "Workshop"
  belongs_to :workshop_child, class_name: "Workshop"

  validates :series_order, presence: true, numericality: { only_integer: true, greater_than: 0 }

  def series_description_for(spanish: false, length: nil)
    description =
      if spanish
        series_description_spanish.presence || series_description.presence
      else
        series_description.presence
      end

    if description.present?
      length ? description.truncate(length) : description
    else
      workshop.formatted_objective(length: length)
    end
  end
end