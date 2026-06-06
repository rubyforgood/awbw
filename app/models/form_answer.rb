class FormAnswer < ApplicationRecord
  belongs_to :form_field, optional: true
  belongs_to :form_submission

  def name
    "#{question_name_when_answered.presence || form_field&.name}: #{submitted_answer}"
  end
end
