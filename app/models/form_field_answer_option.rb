# frozen_string_literal: true

class FormFieldAnswerOption < ApplicationRecord
  belongs_to :form_field
  belongs_to :answer_option

  def name
    answer_option&.name
  end
end
