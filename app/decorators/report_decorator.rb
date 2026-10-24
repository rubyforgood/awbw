class ReportDecorator < ApplicationDecorator
  def windows_type_name
    name.titleize
  end

  def formatted_title
    type.titleize
  end

  def monthly?
    type.include?("Monthly")
  end

  def display_date
    date ? date.strftime : created_at.strftime
  end

  def display_sectors
    sectors.pluck(:name).to_sentence if sectors
  end
end
