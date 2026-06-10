class FormFieldAnswerOption < ApplicationRecord
  belongs_to :form_field
  belongs_to :answer_option

  def name
    answer_option.name if answer_option
  end

  # Virtual attribute used by the form builder to edit an option's text.
  alias_method :option_name, :name

  # Editing the text re-points this join at a matching AnswerOption (creating
  # one if needed) rather than renaming the existing record, which is shared
  # across fields (built via AnswerOption.find_or_create_by!) — renaming it
  # would change every other field that uses the same option.
  def option_name=(value)
    value = value.to_s.strip
    self.answer_option = if value.present?
      AnswerOption.find_or_create_by!(name: value) do |option|
        option.position = (AnswerOption.maximum(:position) || 0) + 1
      end
    end
  end
end
