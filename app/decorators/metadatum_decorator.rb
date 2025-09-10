# frozen_string_literal: true

class MetadatumDecorator < Draper::Decorator
  delegate_all
  decorates_association :categories

  def display_name
    name.titleize
  end
end
