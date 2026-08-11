class CategoryDecorator < ApplicationDecorator
  def title
    name
  end

  def detail(length: nil)
    "#{category_type.name}: #{name}"
  end

  # Trailing-underscore names (e.g. StoryPopulation "Children_") exist only to
  # free the clean name for AgeRange — never show the underscore to users.
  def display_name
    name.to_s.chomp("_")
  end

  # Age-range label with the range appended, e.g. "Children (0-12)". The range
  # lives in the description column so the stored name stays clean.
  def age_group_label
    description.present? ? "#{display_name} (#{description})" : display_name
  end
end
