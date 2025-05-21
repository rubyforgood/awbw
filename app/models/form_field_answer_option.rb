class FormFieldAnswerOption < ApplicationRecord
  belongs_to :form_field
  belongs_to :answer_option

  def name
    answer_option.name if answer_option
  end
end
