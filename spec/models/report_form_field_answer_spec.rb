require 'rails_helper'

RSpec.describe ReportFormFieldAnswer do

  describe 'associations' do
    it { should belong_to(:report) }
    it { should belong_to(:form_field) }
    it { should belong_to(:answer_option).optional }
  end
end