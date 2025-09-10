# frozen_string_literal: true

require "rails_helper"

RSpec.describe(ReportFormFieldAnswer) do
  describe "associations" do
    it { is_expected.to(belong_to(:report)) }
    it { is_expected.to(belong_to(:form_field)) }
    it { is_expected.to(belong_to(:answer_option).optional) }
  end
end
