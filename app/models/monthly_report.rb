class MonthlyReport < ApplicationRecord
  self.table_name = "reports"
  self.inheritance_column = nil

  include Reportable

  default_scope { where(type: "MonthlyReport") }
  before_validation :ensure_type, on: :create

  PARTICIPANT_ONGOING_QUESTION = "Total # On-going Participants"
  PARTICIPANT_FIRST_TIME_QUESTION = "Total # First-Time Participants"

  def self.model_name
    ActiveModel::Name.new(self, nil, "MonthlyReport")
  end

  def self.participant_field_ids(question)
    FormField.where(question: question, status: 1).pluck(:id)
  end

  def on_going_participants
    if form_builder
      field = form_builder.form_fields.find_by(question: PARTICIPANT_ONGOING_QUESTION, status: 1)
      field.answer(self) if field
    end
  end

  def new_participants
    if form_builder
      field = form_builder.form_fields.find_by(question: PARTICIPANT_FIRST_TIME_QUESTION, status: 1)
      field.answer(self) if field
    end
  end

  def month
    date.strftime("%B")
  end

  private

  def ensure_type
    self.type ||= "MonthlyReport"
  end
end
