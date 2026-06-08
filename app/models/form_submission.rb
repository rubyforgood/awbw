class FormSubmission < ApplicationRecord
  belongs_to :person
  belongs_to :form
  has_many :form_answers, dependent: :destroy
  has_many :payments

  accepts_nested_attributes_for :form_answers
end
