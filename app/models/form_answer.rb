class FormAnswer < ApplicationRecord
  belongs_to :form_field, optional: true
  belongs_to :form_submission

  def name
    "#{question_text.presence || form_field&.question}: #{question_answer}"
  end
end
