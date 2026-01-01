class MetadatumDecorator < ApplicationDecorator
  decorates_association :categories

  def display_name
    name.titleize
  end
end
