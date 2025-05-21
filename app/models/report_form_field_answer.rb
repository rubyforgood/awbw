class ReportFormFieldAnswer < ApplicationRecord
  belongs_to :report
  belongs_to :form_field
  belongs_to :answer_option
  attr_accessor :_create

  def name
    "#{form_field.question} - #{response}" unless form_field.nil?
  end

  def response
    answer_option ? answer_option.name : answer
  end
end
