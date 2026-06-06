class ReportFormFieldAnswer < ApplicationRecord
  attr_accessor :_create

  belongs_to :report, optional: true
  belongs_to :workshop_log, optional: true
  belongs_to :form_field
  belongs_to :answer_option, optional: true

  def name
    "#{form_field.name} - #{response}" unless form_field.nil?
  end

  def response
    answer_option ? answer_option.name : answer
  end
end
